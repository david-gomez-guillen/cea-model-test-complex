# Generates the targets of every calibration scheme from the hidden truth of
# tests/truth.R, and writes them into CALIBRATION.TARGETS of
# thalassa_interface.R, between its TARGETS-BEGIN and TARGETS-END markers.
#
#   Rscript tests/make_targets.R      (from the directory of the model)
#
# The values are kept to 10 significant digits, so the truth fits them to
# within a chi-square of about 1e-12: the minimum of every scheme is known, and
# it is 0 for all practical purposes.

source('thalassa_interface.R')
source('tests/truth.R')

base.parameters <- function() {
  values <- lapply(get.parameters(), function(p) p$base.value)
  names(values) <- sapply(get.parameters(), function(p) p$name)
  values
}

scheme.targets <- function(scheme) {
  pars <- base.parameters()
  truth <- true.parameters(scheme)
  for (name in names(truth)) pars[[name]] <- as.list(truth[[name]])
  results <- run.simulation('no_intervention', pars)
  target.names <- list(
    incidence='Cancer incidence',
    natural_history=c('Cancer incidence', 'Local stage share'),
    full=c('Cancer incidence', 'Local stage share', 'Cancer mortality')
  )[[scheme]]
  targets <- list()
  for (name in target.names) {
    values <- signif(results[[TARGET.TYPES[[name]]$output]]$no_intervention, 10)
    targets[[name]] <- setNames(as.list(values), get.strata())
  }
  targets
}

format.targets <- function(scheme, targets) {
  lines <- sprintf('  %s=list(', scheme)
  for (i in seq_along(targets)) {
    name <- names(targets)[i]
    values <- targets[[i]]
    entries <- sprintf('`%s`=%s', names(values), sapply(values, format, digits=10))
    lines <- c(lines,
               sprintf('    `%s`=list(', name),
               paste0('      ', entries, c(rep(',', length(entries) - 1), '')),
               sprintf('    )%s', if (i < length(targets)) ',' else ''))
  }
  c(lines, '  )')
}

schemes <- c('incidence', 'natural_history', 'full')
block <- unlist(lapply(seq_along(schemes), function(i) {
  lines <- format.targets(schemes[i], scheme.targets(schemes[i]))
  if (i < length(schemes)) lines[length(lines)] <- paste0(lines[length(lines)], ',')
  lines
}))

interface <- readLines('thalassa_interface.R')
begin <- grep('# TARGETS-BEGIN', interface, fixed=TRUE)
end <- grep('# TARGETS-END', interface, fixed=TRUE)
writeLines(c(interface[1:begin], block, interface[end:length(interface)]), 'thalassa_interface.R')
cat('Targets written to thalassa_interface.R\n')
