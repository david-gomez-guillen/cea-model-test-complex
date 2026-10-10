# The hidden truth the calibration targets are generated from, kept out of
# sight of anything a calibration reads. The agentic method of thalassa.optim
# sends the LLM every .R file of the model but those under tests/, which is why
# this lives here.
#
# Each profile is given at the middle of each five-year age group (32, ..., 82).
# They are smooth, as the training set of the latent space assumes, but not all
# of the family it draws from: onset and cancer death are log-quadratic and
# log-linear, which it holds, while progression is logistic, which it can only
# approximate.

TRUE.AGES <- seq(32, 82, by=5)

true.profiles <- function() {
  t <- (TRUE.AGES - 57) / 25
  list(
    p.onset=0.007 * exp(0.9 * t - 0.3 * t^2),
    p.progression=0.24 + 0.18 / (1 + exp(-(TRUE.AGES - 60) / 6)),
    p.cancer.death=0.18 * exp(0.45 * t)
  )
}

# The true values of the parameters each scheme calibrates. The targets of a
# scheme are generated with these and every other parameter at its base value,
# so that every scheme can be fitted exactly, from its own parameters alone.
true.parameters <- function(scheme) {
  profiles <- true.profiles()
  parameters <- list(
    incidence='p.onset',
    natural_history=c('p.onset', 'p.progression'),
    full=c('p.onset', 'p.progression', 'p.cancer.death')
  )[[scheme]]
  profiles[parameters]
}
