# How hard each calibration scheme is, measured at its hidden truth.
#
#   Rscript tests/difficulty.R      (from the directory of the model)
#
# For each scheme it reports:
#   - the error at the truth (0 but for the rounding of the targets) and at the
#     initial guess;
#   - the condition number of the Hessian of the error at the truth, in the
#     coordinates the optimizers search, the unit cube of the search box
#     initial_guess * (1 ± 1). The error is a sum of squares that is 0 at the
#     truth, so its Hessian there is 2 J'J, J being the Jacobian of the
#     residuals measured in standard errors;
#   - how precisely the parameters have to be set for a chi-square of 1, i.e. a
#     fit within one standard error overall, along the stiffest direction;
#   - the weakest direction, the combination of parameters the targets say
#     least about;
#   - the lowest error reachable within the family of profiles the latent space
#     training set draws from (log-parabolas through three anchors), which is
#     the floor of a search confined to it.

source('thalassa_interface.R')
source('tests/truth.R')

SCOPE <- 1

base.parameters <- function() {
  values <- lapply(get.parameters(), function(p) p$base.value)
  names(values) <- sapply(get.parameters(), function(p) p$name)
  values
}

# The error of a calibration vector laid out as the scheme's, parameter by
# parameter and stratum by stratum, as calibrate() calls the error function.
scheme.error <- function(scheme, x) {
  pars <- base.parameters()
  n.strata <- length(get.strata())
  for (i in seq_along(scheme$parameters))
    pars[[scheme$parameters[i]]] <- as.list(x[(i - 1) * n.strata + 1:n.strata])
  calibration.error(pars, scheme$target)
}

# Residuals in standard errors, the terms the chi-square adds up the squares of.
scheme.residuals <- function(scheme, x) {
  output <- scheme.error(scheme, x)$output
  unlist(lapply(names(scheme$target), function(name) {
    type <- TARGET.TYPES[[name]]
    target.values <- unlist(scheme$target[[name]])
    se <- if (is.null(type$relative.se)) type$absolute.se else type$relative.se * target.values
    (output[[name]] - target.values) / se
  }))
}

schemes <- get.calibration.schemes()
for (name in names(schemes)) {
  scheme <- schemes[[name]]
  truth <- unlist(true.parameters(name))
  x0 <- scheme$initial_guess
  width <- 2 * SCOPE * x0

  # Central differences in the unit cube of the search box.
  h <- 1e-6
  J <- sapply(seq_along(truth), function(k) {
    up <- truth; down <- truth
    up[k] <- up[k] + h * width[k]
    down[k] <- down[k] - h * width[k]
    (scheme.residuals(scheme, up) - scheme.residuals(scheme, down)) / (2 * h)
  })
  s <- svd(J)
  stiffest <- 1 / max(s$d)

  # The best log-parabola profiles, starting from the ones through the truth at
  # the youngest, middle and oldest age groups.
  n.strata <- length(get.strata())
  age <- seq(-1, 1, length.out=n.strata)
  basis <- cbind((age^2 - age) / 2, 1 - age^2, (age^2 + age) / 2)
  from.anchors <- function(a) {
    unlist(lapply(seq_along(scheme$parameters), function(i) {
      columns <- (i - 1) * n.strata + 1:n.strata
      x0[columns] * exp(drop(basis %*% a[(i - 1) * 3 + 1:3]))
    }))
  }
  start <- unlist(lapply(seq_along(scheme$parameters), function(i) {
    columns <- (i - 1) * n.strata + 1:n.strata
    log(truth[columns][c(1, 5, 9)] / x0[columns][c(1, 5, 9)])
  }))
  family <- optim(start, function(a) scheme.error(scheme, from.anchors(a))$error,
                  method='BFGS', control=list(maxit=500, reltol=1e-14))

  cat(sprintf('\n== %s: %d parameters, %d targets\n', name, length(truth), nrow(J)))
  cat(sprintf('  error at the truth:          %.3g\n', scheme.error(scheme, truth)$error))
  cat(sprintf('  error at the initial guess:  %.4g\n', scheme.error(scheme, x0)$error))
  cat(sprintf('  condition number (Hessian):  %.3g\n', (max(s$d) / min(s$d))^2))
  cat(sprintf('  chi-square of 1 along the stiffest direction: a move of %.2g of the search box,\n', stiffest))
  cat(sprintf('    %.2g relative to the parameters at the truth\n',
              stiffest * sqrt(sum((s$v[, 1] * width / truth)^2))))
  cat(sprintf('  error floor of the smooth family: %.4g\n', family$value))
  cat('  weakest direction, in the unit cube of the search box:\n')
  weakest <- matrix(s$v[, ncol(J)], nrow=n.strata,
                    dimnames=list(get.strata(), scheme$parameters))
  print(round(weakest, 3))
}
