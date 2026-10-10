# Whether a calibration scheme can be solved without optimizing at all, by the
# reasoning an LLM is most likely to apply: each parameter has a target it
# drives (onset drives incidence, progression lowers the local stage share,
# cancer death drives mortality), so when a target is missed by some factor,
# scale the parameter of that age group by the same factor, and repeat.
#
#   Rscript tests/rescaling.R      (from the directory of the model)
#
# It is run with each parameter paired with its target in the same age group
# (lag 0), and in the age group one or two later (lag 1, 2), which is how the
# delay between onset and diagnosis would be allowed for. A scheme this solves
# in a few iterations is no test of an optimizer, whatever its condition
# number: in a cohort model the targets of an age group depend only on the
# parameters of that group and earlier ones, and as long as each target
# responds clearly to the parameter of its own group, this converges.
#
# It prints the error at a few iterations of 40.

source('thalassa_interface.R')

ITERATIONS <- 40
PAIRS <- list(
  p.onset=list(target='Cancer incidence', direction=1),
  p.progression=list(target='Local stage share', direction=-1),
  p.cancer.death=list(target='Cancer mortality', direction=1)
)

base.parameters <- function() {
  values <- lapply(get.parameters(), function(p) p$base.value)
  names(values) <- sapply(get.parameters(), function(p) p$name)
  values
}

n.strata <- length(get.strata())
schemes <- get.calibration.schemes()
for (name in names(schemes)) {
  scheme <- schemes[[name]]
  for (lag in 0:2) {
    x <- scheme$initial_guess
    upper <- pmin(1, 2 * scheme$initial_guess)
    errors <- numeric(ITERATIONS)
    for (iteration in 1:ITERATIONS) {
      pars <- base.parameters()
      for (i in seq_along(scheme$parameters))
        pars[[scheme$parameters[i]]] <- as.list(x[(i - 1) * n.strata + 1:n.strata])
      result <- calibration.error(pars, scheme$target)
      errors[iteration] <- result$error
      if (!is.finite(result$error)) break
      for (i in seq_along(scheme$parameters)) {
        pair <- PAIRS[[scheme$parameters[i]]]
        ratio <- unlist(scheme$target[[pair$target]]) / result$output[[pair$target]]
        groups <- 1:(n.strata - lag)
        columns <- (i - 1) * n.strata + groups
        x[columns] <- pmin(upper[columns], pmax(1e-8, x[columns] * ratio[groups + lag]^pair$direction))
      }
    }
    shown <- c(1, 2, 3, 5, 10, 20, 40)
    cat(sprintf('%-16s lag %d: %s\n', name, lag,
                paste(sprintf('%.3g', errors[shown]), collapse='  ')))
  }
}
