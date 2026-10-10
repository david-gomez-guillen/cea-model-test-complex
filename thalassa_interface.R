library(ggplot2)

source('model.R')

get.overview <- function() {
  # Markdown shown in the Overview tab (see get.overview.markdown() in shiny-cea).
  # The text lives in overview.md. Everything described there is derived from
  # simulate() in model.R and from the rest of this interface, so it must be kept
  # in sync with them.
  return(paste(readLines('overview.md'), collapse='\n'))
}

get.strategies <- function() {
  # Hardcoded strategies for the model. In a real application, these could be loaded from a file or database.
  # The descriptions and attributes describe what each strategy changes in
  # simulate() in model.R, and must be kept in sync with it.
  return(list(
    list(
      name='no_intervention',
      display.name='No intervention',
      description='Natural history of the cancer: it is only diagnosed once it causes symptoms, and diagnosed cases get usual care. The reference the other strategies are compared against.',
      attributes=list(intervention='None', population='Nobody', effect='None')
    ),
    list(
      name='screening',
      display.name='Screening',
      description='Everyone alive and undiagnosed is screened once a year, at cost.screening each, which finds a share screening.sensitivity.local of the preclinical local cancers and screening.sensitivity.advanced of the preclinical advanced ones.',
      attributes=list(intervention='Screening', population='Undiagnosed', effect='Earlier diagnosis')
    ),
    list(
      name='treatment',
      display.name='Treatment',
      description='Every diagnosed person is treated, at cost.treatment a year each, which multiplies their hazard of dying of the cancer by hr.treatment.',
      attributes=list(intervention='Treatment', population='Diagnosed', effect='Lower cancer mortality')
    )
  ))
}

get.strategy.attributes <- function() {
  # What describes the strategies, shown as columns of the Strategies tab. Only
  # the intervention is drawn on the base case plot, as the shape of the point.
  return(list(
    intervention=list(
      label='Intervention',
      plot='shape',
      values=c(None='x', Screening='circle', Treatment='square')
    ),
    population='Applied to',
    effect='Effect'
  ))
}

# Constraints: each returns TRUE when the value is acceptable, or the message
# shown for it when it is not.
symptoms.local.below.symptoms.advanced <- function(par.name, params) {
  if (params[['p.symptoms.local']] >= params[['p.symptoms.advanced']]) 'A local cancer must cause symptoms less often than an advanced one' else TRUE
}


get.parameters <- function() {
  # Hardcoded parameters for the model. In a real application, these could be loaded from a file or database.
  # p.onset, p.progression and p.cancer.death can be given one value per age
  # group, which is what the calibration schemes estimate. Their base values
  # are flat, the same for every age.
  return(list(
    list(
      name='p.onset',
      display.name='Annual probability of developing a (preclinical) cancer while healthy',
      base.value=0.004,
      distribution='beta',
      class='Natural history',
      min.value=0,
      max.value=1
    ),
    list(
      name='p.progression',
      display.name='Annual probability of a preclinical local cancer becoming advanced',
      base.value=0.3,
      distribution='beta',
      class='Natural history',
      min.value=0,
      max.value=1
    ),
    list(
      name='p.symptoms.local',
      display.name='Annual probability of a preclinical local cancer causing symptoms (and being diagnosed)',
      base.value=0.05,
      distribution='beta',
      class='Natural history',
      min.value=0,
      max.value=1,
      constraints=list(symptoms.local.below.symptoms.advanced)
    ),
    list(
      name='p.symptoms.advanced',
      display.name='Annual probability of a preclinical advanced cancer causing symptoms (and being diagnosed)',
      base.value=0.25,
      distribution='beta',
      class='Natural history',
      min.value=0,
      max.value=1,
      constraints=list(symptoms.local.below.symptoms.advanced)
    ),
    list(
      name='p.cancer.death',
      display.name='Annual probability of dying of a diagnosed advanced cancer',
      base.value=0.2,
      distribution='beta',
      class='Mortality',
      min.value=0,
      max.value=1
    ),
    list(
      name='rr.cancer.death.local',
      display.name='Hazard of dying of a diagnosed local cancer, relative to an advanced one',
      base.value=0.08,
      distribution='lognormal',
      class='Mortality',
      min.value=0
    ),
    list(
      name='p.other.death',
      display.name='Annual probability of dying of other causes at age 30',
      base.value=0.0008,
      distribution='beta',
      class='Mortality',
      min.value=0,
      max.value=1
    ),
    list(
      name='other.death.growth',
      display.name='Yearly growth of the hazard of dying of other causes (Gompertz)',
      base.value=0.085,
      distribution='normal',
      class='Mortality',
      min.value=0
    ),
    list(
      name='screening.sensitivity.local',
      display.name='Sensitivity of screening for preclinical local cancers',
      base.value=0.55,
      distribution='beta',
      class='Screening',
      min.value=0,
      max.value=1
    ),
    list(
      name='screening.sensitivity.advanced',
      display.name='Sensitivity of screening for preclinical advanced cancers',
      base.value=0.85,
      distribution='beta',
      class='Screening',
      min.value=0,
      max.value=1
    ),
    list(
      name='cost.screening',
      display.name='Cost of one screening test',
      base.value=150,
      distribution='gamma',
      class='Screening',
      min.value=0
    ),
    list(
      name='hr.treatment',
      display.name='Hazard ratio of cancer death under treatment',
      base.value=0.7,
      distribution='lognormal',
      class='Treatment',
      min.value=0
    ),
    list(
      name='cost.treatment',
      display.name='Annual cost of treatment per diagnosed person',
      base.value=30000,
      distribution='gamma',
      class='Treatment',
      min.value=0
    ),
    list(
      name='cost.care.local',
      display.name='Annual cost of usual care of a diagnosed local cancer',
      base.value=5000,
      distribution='gamma',
      class='General',
      min.value=0
    ),
    list(
      name='cost.care.advanced',
      display.name='Annual cost of usual care of a diagnosed advanced cancer',
      base.value=25000,
      distribution='gamma',
      class='General',
      min.value=0
    ),
    list(
      name='utility.local',
      display.name='Utility of a year lived with a diagnosed local cancer',
      base.value=0.85,
      distribution='beta',
      class='General',
      min.value=0,
      max.value=1
    ),
    list(
      name='utility.advanced',
      display.name='Utility of a year lived with a diagnosed advanced cancer',
      base.value=0.55,
      distribution='beta',
      class='General',
      min.value=0,
      max.value=1
    ),
    list(
      name='discount',
      display.name='Discount rate',
      base.value=0.03,
      class='General',
      min.value=0,
      max.value=1
    )
  ))
}

get.strata <- function() {
  # Hardcoded strata for the model. In a real application, these could be loaded from a file or database.
  return(c('30-34', '35-39', '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74'))
}

get.model.states <- function() {
  # State diagram shown in the Overview tab, next to the text of overview.md. It
  # describes the transition matrix of simulate() in model.R and must be kept in
  # sync with it.
  return(list(
    title='Model states',
    description='The seven states of the cohort and the monthly transitions between them. Death from other causes, possible from every living state, is drawn from Healthy only. Hover a state or a transition for what drives it.',
    nodes=data.frame(
      id=c('healthy', 'preclinical.local', 'preclinical.advanced',
           'diagnosed.local', 'diagnosed.advanced', 'cancer.death', 'other.death'),
      label=c('Healthy', 'Preclinical local', 'Preclinical advanced',
              'Diagnosed local', 'Diagnosed advanced', 'Cancer death', 'Other death'),
      description=c(
        'Alive and cancer-free. The whole cohort starts here.',
        'A local cancer nobody knows about yet: no symptoms, no costs, no loss of health.',
        'An advanced cancer nobody knows about yet: no symptoms, no costs, no loss of health.',
        'A local cancer, diagnosed after causing symptoms or found by screening.',
        'An advanced cancer, diagnosed after causing symptoms or found by screening.',
        'Absorbing state, reached from both diagnosed states.',
        'Absorbing state, reached from every living state.'
      )
    ),
    edges=data.frame(
      from=c('healthy', 'preclinical.local', 'preclinical.local', 'preclinical.advanced',
             'diagnosed.local', 'diagnosed.advanced', 'healthy'),
      to=c('preclinical.local', 'preclinical.advanced', 'diagnosed.local', 'diagnosed.advanced',
           'cancer.death', 'cancer.death', 'other.death'),
      label=c('Onset', 'Progression', 'Symptoms', 'Symptoms', 'Death', 'Death', 'Death'),
      description=c(
        'p.onset, one value per age group.',
        'p.progression, one value per age group.',
        'p.symptoms.local, plus a share screening.sensitivity.local once a year under screening.',
        'p.symptoms.advanced, plus a share screening.sensitivity.advanced once a year under screening.',
        'p.cancer.death times rr.cancer.death.local, times hr.treatment under treatment.',
        'p.cancer.death, one value per age group, times hr.treatment under treatment.',
        'p.other.death at age 30, growing by other.death.growth a year. Same from every living state.'
      )
    )
  ))
}

get.code.sample <- function() {
  # Code shown in the Code panel of the Overview tab, one tab per entry, for
  # whoever wants to see how the model works. The whole of model.R is written to
  # be read, so it is shown as it is.
  return(list(
    `model.R`=paste(readLines('model.R'), collapse='\n')
  ))
}

run.simulation <- function(strategies, pars) {
  # The pars vector should be transformed to the format expected by the simulate function.
  # This is a simple mapping based on the parameter names.
  results <- simulate(strategies,
                      p.onset=pars[['p.onset']],
                      p.progression=pars[['p.progression']],
                      p.symptoms.local=pars[['p.symptoms.local']],
                      p.symptoms.advanced=pars[['p.symptoms.advanced']],
                      p.cancer.death=pars[['p.cancer.death']],
                      rr.cancer.death.local=pars[['rr.cancer.death.local']],
                      p.other.death=pars[['p.other.death']],
                      other.death.growth=pars[['other.death.growth']],
                      screening.sensitivity.local=pars[['screening.sensitivity.local']],
                      screening.sensitivity.advanced=pars[['screening.sensitivity.advanced']],
                      hr.treatment=pars[['hr.treatment']],
                      cost.screening=pars[['cost.screening']],
                      cost.treatment=pars[['cost.treatment']],
                      cost.care.local=pars[['cost.care.local']],
                      cost.care.advanced=pars[['cost.care.advanced']],
                      utility.local=pars[['utility.local']],
                      utility.advanced=pars[['utility.advanced']],
                      discount=pars[['discount']])
  return(results)
}

# ---- Calibration -------------------------------------------------------------

# The registry figures a target can be, each with the output of simulate() it
# is compared against and its standard error: the uncertainty of the reported
# value, which sets how closely the model has to reproduce it. Incidence and
# mortality come from large registries and are known to within a fraction of a
# percent; the stage at diagnosis is often missing from records, and is known to
# within a percentage point.
TARGET.TYPES <- list(
  `Cancer incidence`=list(output='incidence', relative.se=0.005),
  `Local stage share`=list(output='local.share', absolute.se=1),
  `Cancer mortality`=list(output='mortality', relative.se=0.01)
)

# The targets of every scheme, generated by tests/make_targets.R.
CALIBRATION.TARGETS <- list(
  # TARGETS-BEGIN
  incidence=list(
    `Cancer incidence`=list(
      `30-34`=8.941149993,
      `35-39`=31.19871784,
      `40-44`=57.18714078,
      `45-49`=91.20702362,
      `50-54`=137.0903512,
      `55-59`=196.7787718,
      `60-64`=270.312149,
      `65-69`=355.501592,
      `70-74`=447.7241717
    )
  ),
  natural_history=list(
    `Cancer incidence`=list(
      `30-34`=8.160013707,
      `35-39`=29.35672098,
      `40-44`=55.14563103,
      `45-49`=89.46250253,
      `50-54`=137.0785634,
      `55-59`=201.2413186,
      `60-64`=281.407703,
      `65-69`=372.1073134,
      `70-74`=466.3764311
    ),
    `Local stage share`=list(
      `30-34`=33.38802177,
      `35-39`=22.66253904,
      `40-44`=19.87406777,
      `45-49`=18.46813122,
      `50-54`=16.90863865,
      `55-59`=14.94430577,
      `60-64`=12.92561824,
      `65-69`=11.33467416,
      `70-74`=10.30356499
    )
  ),
  full=list(
    `Cancer incidence`=list(
      `30-34`=8.159962169,
      `35-39`=29.35409689,
      `40-44`=55.13025243,
      `45-49`=89.42020391,
      `50-54`=137.0041113,
      `55-59`=201.1720375,
      `60-64`=281.4978105,
      `65-69`=372.7347152,
      `70-74`=468.2163084
    ),
    `Local stage share`=list(
      `30-34`=33.38802177,
      `35-39`=22.66253904,
      `40-44`=19.87406777,
      `45-49`=18.46813122,
      `50-54`=16.90863865,
      `55-59`=14.94430577,
      `60-64`=12.92561824,
      `65-69`=11.33467416,
      `70-74`=10.30356499
    ),
    `Cancer mortality`=list(
      `30-34`=0.8485415985,
      `35-39`=7.973117318,
      `40-44`=23.59907652,
      `45-49`=48.19171855,
      `50-54`=84.71126614,
      `55-59`=137.9527083,
      `60-64`=211.9398999,
      `65-69`=305.8253014,
      `70-74`=412.8647573
    )
  )
  # TARGETS-END
)

get.calibration.schemes <- function() {
  return(list(
    incidence=list(
      description='Onset by age group against cancer incidence (9 values, 9 targets)',
      parameters='p.onset',
      target=CALIBRATION.TARGETS$incidence,
      strata=get.strata(),
      initial_guess=rep(.004, 9),
      error_function=calibration.error,
      latent_space_training_set=generate.training.dataset,
      other.plots=list(relative.deviation.plot(CALIBRATION.TARGETS$incidence))
    ),
    natural_history=list(
      description='Onset and progression by age group against incidence and stage at diagnosis (18 values, 18 targets)',
      parameters=c('p.onset', 'p.progression'),
      target=CALIBRATION.TARGETS$natural_history,
      strata=get.strata(),
      initial_guess=c(rep(.004, 9), rep(.3, 9)),
      error_function=calibration.error,
      latent_space_training_set=generate.training.dataset,
      other.plots=list(relative.deviation.plot(CALIBRATION.TARGETS$natural_history))
    ),
    full=list(
      description='Onset, progression and cancer death by age group against incidence, stage at diagnosis and mortality (27 values, 27 targets)',
      parameters=c('p.onset', 'p.progression', 'p.cancer.death'),
      target=CALIBRATION.TARGETS$full,
      strata=get.strata(),
      initial_guess=c(rep(.004, 9), rep(.3, 9), rep(.2, 9)),
      error_function=calibration.error,
      latent_space_training_set=generate.training.dataset,
      other.plots=list(relative.deviation.plot(CALIBRATION.TARGETS$full))
    )))
}

calibration.error <- function(pars, target) {
  calibration.strategy <- 'no_intervention'
  # The error is a chi-square: the sum over every target of the squared
  # difference between the simulated and the target value, measured in standard
  # errors of the target. A fit within one standard error everywhere scores
  # about the number of targets, and the exact fit scores 0.
  #
  # The output keeps the order of the target, one value per target and stratum,
  # which is how the simulated curves are matched to the targets they belong to.
  result <- tryCatch({
    results <- run.simulation(calibration.strategy, pars)
    error <- 0
    output <- list()
    for (name in names(target)) {
      type <- TARGET.TYPES[[name]]
      simulated <- results[[type$output]][[calibration.strategy]]
      names(simulated) <- get.strata()
      target.values <- unlist(target[[name]])
      simulated <- simulated[names(target.values)]
      se <- if (is.null(type$relative.se)) type$absolute.se else type$relative.se * target.values
      error <- error + sum(((simulated - target.values) / se)^2)
      output[[name]] <- simulated
    }
    if (!is.finite(error)) stop('the simulation produced no finite error')
    list(error=error, output=output)
  }, error=function(e) {
    output <- lapply(target, function(values) {
      simulated <- rep(NA, length(values))
      names(simulated) <- names(values)
      simulated
    })
    list(error=Inf, output=output)
  })
  return(result)
}

# Additional plot of the calibration tab: how far each simulated value is from
# its target, in percent of the target. The three targets have very different
# scales, so on the calibration curve plot the stage share is squashed against
# the axis; here every target is on the same footing, and the misses that the
# chi-square error punishes, a fraction of a percent, can be seen.
relative.deviation.plot <- function(target) {
  force(target)
  function(data) {
    if (is.null(data)) return(NULL)
    rows <- list()
    for (name in names(target)) {
      target.values <- unlist(target[[name]])
      simulated <- data[paste0('sim_', name, '.', names(target.values))]
      if (length(simulated) != length(target.values) || all(is.na(simulated))) next
      deviation <- 100 * (as.numeric(simulated) / target.values - 1)
      rows[[name]] <- data.frame(stratum=names(target.values), target=name, deviation=deviation,
                                 text=sprintf('%s, %s: %+.3f%%', name, names(target.values), deviation))
    }
    if (length(rows) == 0) return(NULL)
    plt.df <- do.call(rbind, rows)
    plt.df$target <- factor(plt.df$target, levels=names(target))
    ggplot(plt.df, aes(x=stratum, y=deviation, color=target, group=target, text=text)) +
      geom_hline(yintercept=0, color='grey50') +
      geom_line() +
      geom_point() +
      labs(x='Age group', y='Simulated vs target (%)', color='') +
      theme_minimal()
  }
}

generate.training.dataset <- function(initial_guess, n, ...) {
  # Plausible calibration vectors to train a latent space on. Each calibrated
  # parameter is a profile over the age groups, and the profiles of real
  # natural histories are smooth: a probability rises or falls steadily with
  # age, it does not jump up and down from one age group to the next. So each
  # profile is drawn by picking, at random, how far from the initial guess it is
  # at the youngest, middle and oldest age groups, on a log scale, and joining
  # those three by the parabola through them. The values are kept within the
  # search box, initial_guess * (1 ± variation), and below 1.
  f.pars <- list(...)
  variation <- f.pars$variation

  n.strata <- length(get.strata())
  n.params <- length(initial_guess) %/% n.strata
  age <- seq(-1, 1, length.out=n.strata)
  # The parabola through (-1, a), (0, b), (1, c).
  basis <- cbind((age^2 - age) / 2, 1 - age^2, (age^2 + age) / 2)

  # Down to a twentieth of the initial guess, which a box reaching down to 0
  # does not bound.
  lowest <- log(max(1 - variation, 0.05))
  highest <- log(1 + variation)

  dataset <- matrix(NA, nrow=n, ncol=length(initial_guess))
  for (i in 1:n) {
    for (p in 1:n.params) {
      columns <- (p - 1) * n.strata + 1:n.strata
      anchors <- runif(3, min=lowest, max=highest)
      profile <- initial_guess[columns] * exp(drop(basis %*% anchors))
      dataset[i, columns] <- pmin(1, initial_guess[columns] * (1 + variation), profile)
    }
  }

  return(dataset)
}

generate.training.dataset.independent <- function(initial_guess, n, ...) {
  # The training set of a model that knows nothing about the shape of the
  # profiles: every value drawn on its own, scaling the initial guess by a
  # uniform random factor within the search box. It is not used by any scheme;
  # it is here to compare against generate.training.dataset(), e.g.
  #   calibrate(path, 'full', latent=latent_space('ae', training_set=function(n)
  #     generate.training.dataset.independent(x0, n, variation=1)))
  f.pars <- list(...)
  variation <- f.pars$variation

  n_params <- length(initial_guess)

  dataset <- matrix(NA, nrow=n, ncol=n_params)

  for(i in 1:n) {
    factors <- runif(n_params, min=1-variation, max=1+variation)
    dataset[i,] <- pmin(1, initial_guess * factors)
  }

  return(dataset)
}

# ### TEST
#
# strategies <- sapply(get.strategies(), function(s) s$name)
# param.info <- get.parameters()
# param.values <- lapply(param.info, function(p) p$base.value)
# names(param.values) <- sapply(param.info, function(p) p$name)
#
# results <- run.simulation(strategies, param.values)
# print(results$summary)
