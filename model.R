# A cost-effectiveness model of a hypothetical cancer with a hidden natural
# history.
#
# It is a Markov cohort model. Rather than following people one by one, it keeps
# track of which share of a group of people, the cohort, is in each health state,
# and moves those shares from state to state once a month.
#
# The cancer starts silently. For a while it is preclinical: it is there, but
# nobody knows, and it can grow from a local to an advanced tumour before it
# causes symptoms. Only when it does is it diagnosed, and only diagnosed cancers
# are seen by a cancer registry. Most of what drives the disease is therefore
# never observed directly, and has to be inferred from what registries report.
#
#   States:      Healthy, Preclinical local, Preclinical advanced,
#                Diagnosed local, Diagnosed advanced, Cancer death, Other death
#   Cycle:       one month
#   Horizon:     from age 30 to age 74
#   Strategies:  no_intervention, screening, treatment
#
# For each strategy the model adds up what the cohort costs and how much health
# it enjoys. Comparing those two totals between strategies is what a
# cost-effectiveness analysis does.

START.AGE <- 30
END.AGE <- 74
CYCLES.PER.YEAR <- 12

# Results by age are reported per five-year age group: 30-34, 35-39, ..., 70-74.
AGE.GROUP.SIZE <- 5

STATES <- c('healthy',
            'preclinical.local', 'preclinical.advanced',
            'diagnosed.local', 'diagnosed.advanced',
            'cancer.death', 'other.death')

# The value of a parameter at an age. It is either one value for every age or a
# list with one value per age group, in which case the one of the age is used.
value.at.age <- function(value, age) {
  if (is.list(value)) value[[(age - START.AGE) %/% AGE.GROUP.SIZE + 1]] else value
}

# Parameters are given as annual probabilities, which is how they are usually
# reported, but probabilities cannot be added or split between months. Hazards
# (rates) can: a probability p over a year is a constant hazard of -log(1 - p).
# log1p() keeps the small probabilities of this model exact to the last digit,
# which 1 - p would round away.
annual.hazard <- function(p, name) {
  if (!is.finite(p) || p < 0 || p >= 1)
    stop(name, ' must be a probability in [0, 1), not ', p)
  -log1p(-p)
}

# The transition matrix of one month from the annual hazards between states. In
# a month, a person leaves their state with probability 1 - exp(-total hazard),
# and goes to each other state in proportion to its hazard: the hazards compete.
monthly.transitions <- function(hazards) {
  total <- rowSums(hazards)
  leave <- -expm1(-total / CYCLES.PER.YEAR)
  # Dividing by the total recycles it along each row. The dead leave nowhere.
  transitions <- hazards / total * leave
  transitions[total == 0, ] <- 0
  diag(transitions) <- 1 - leave
  transitions
}

simulate <- function(strategies,
                     p.onset,
                     p.progression,
                     p.symptoms.local,
                     p.symptoms.advanced,
                     p.cancer.death,
                     rr.cancer.death.local,
                     p.other.death,
                     other.death.growth,
                     screening.sensitivity.local,
                     screening.sensitivity.advanced,
                     hr.treatment,
                     cost.screening,
                     cost.treatment,
                     cost.care.local,
                     cost.care.advanced,
                     utility.local,
                     utility.advanced,
                     discount) {

  ages <- START.AGE:END.AGE
  n.groups <- length(ages) %/% AGE.GROUP.SIZE

  summary <- data.frame()
  incidence <- list()
  local.share <- list()
  mortality <- list()
  cohort.info <- list()

  for (strategy in strategies) {

    # ---- What the strategy changes ----------------------------------------
    # A strategy is the same model with a few numbers changed. Screening finds
    # preclinical cancers once a year, before they cause symptoms, and is paid
    # for every person screened. Treatment lowers the hazard of dying of a
    # diagnosed cancer, and is paid for every person diagnosed.
    if (!strategy %in% c('no_intervention', 'screening', 'treatment'))
      stop('Unknown strategy: ', strategy)

    screening <- strategy == 'screening'
    treatment <- strategy == 'treatment'

    # What a person in each state costs in a year, and the quality of life of
    # that year: 1 is a year in full health and 0 is being dead. A preclinical
    # cancer causes no symptoms, so it costs nothing and takes no health away.
    state.costs <- c(healthy = 0,
                     preclinical.local = 0, preclinical.advanced = 0,
                     diagnosed.local = cost.care.local + if (treatment) cost.treatment else 0,
                     diagnosed.advanced = cost.care.advanced + if (treatment) cost.treatment else 0,
                     cancer.death = 0, other.death = 0)
    state.utilities <- c(healthy = 1,
                         preclinical.local = 1, preclinical.advanced = 1,
                         diagnosed.local = utility.local,
                         diagnosed.advanced = utility.advanced,
                         cancer.death = 0, other.death = 0)

    # ---- The cohort ---------------------------------------------------------
    # The share of the cohort in each state. Everyone starts healthy, and the
    # shares always add up to 1.
    cohort <- setNames(c(1, 0, 0, 0, 0, 0, 0), STATES)

    # One value per month, filled in as the cohort ages.
    n.cycles <- length(ages) * CYCLES.PER.YEAR
    costs <- numeric(n.cycles)
    utilities <- numeric(n.cycles)
    person.years <- numeric(n.cycles)
    diagnoses <- numeric(n.cycles)
    local.diagnoses <- numeric(n.cycles)
    cancer.deaths <- numeric(n.cycles)
    cohort.trace <- vector('list', n.cycles + 1)
    cohort.trace[[1]] <- cohort

    cycle <- 0
    for (age in ages) {

      # ---- 1. Annual hazards of this year of age ----------------------------
      # The natural history can change with age, so the probabilities that are
      # given per age group are read at the current age. Death from other
      # causes grows exponentially with age (Gompertz), as in life tables.
      h.onset <- annual.hazard(value.at.age(p.onset, age), 'p.onset')
      h.progression <- annual.hazard(value.at.age(p.progression, age), 'p.progression')
      h.symptoms.local <- annual.hazard(p.symptoms.local, 'p.symptoms.local')
      h.symptoms.advanced <- annual.hazard(p.symptoms.advanced, 'p.symptoms.advanced')
      h.cancer.death <- annual.hazard(value.at.age(p.cancer.death, age), 'p.cancer.death')
      if (treatment) h.cancer.death <- h.cancer.death * hr.treatment
      h.other.death <- annual.hazard(p.other.death, 'p.other.death') *
        exp(other.death.growth * (age - START.AGE))

      # ---- 2. Transition matrix -----------------------------------------------
      # Row: the state a person is in now. Column: the state a month later. A
      # preclinical cancer either grows or causes symptoms and is diagnosed at
      # the stage it has reached. Only diagnosed cancers kill, a local one far
      # less than an advanced one. The two dead states are absorbing.
      hazards <- matrix(0, nrow = 7, ncol = 7, dimnames = list(STATES, STATES))
      hazards['healthy', 'preclinical.local'] <- h.onset
      hazards['preclinical.local', 'preclinical.advanced'] <- h.progression
      hazards['preclinical.local', 'diagnosed.local'] <- h.symptoms.local
      hazards['preclinical.advanced', 'diagnosed.advanced'] <- h.symptoms.advanced
      hazards['diagnosed.local', 'cancer.death'] <- h.cancer.death * rr.cancer.death.local
      hazards['diagnosed.advanced', 'cancer.death'] <- h.cancer.death
      hazards[1:5, 'other.death'] <- h.other.death
      transitions <- monthly.transitions(hazards)

      for (month in 1:CYCLES.PER.YEAR) {
        cycle <- cycle + 1
        discount.factor <- 1 / (1 + discount)^((cycle - 1) / CYCLES.PER.YEAR)
        alive <- sum(cohort[1:5])
        new.local <- 0
        new.advanced <- 0
        screening.cost <- 0

        # ---- 3. Screening, once a year ----------------------------------------
        # Everyone alive and not yet diagnosed is screened on their birthday.
        # The test finds a share of the preclinical cancers, which are then
        # diagnosed at the stage they had reached.
        if (screening && month == 1) {
          found.local <- cohort[['preclinical.local']] * screening.sensitivity.local
          found.advanced <- cohort[['preclinical.advanced']] * screening.sensitivity.advanced
          screening.cost <- sum(cohort[1:3]) * cost.screening
          cohort[['preclinical.local']] <- cohort[['preclinical.local']] - found.local
          cohort[['diagnosed.local']] <- cohort[['diagnosed.local']] + found.local
          cohort[['preclinical.advanced']] <- cohort[['preclinical.advanced']] - found.advanced
          cohort[['diagnosed.advanced']] <- cohort[['diagnosed.advanced']] + found.advanced
          new.local <- new.local + found.local
          new.advanced <- new.advanced + found.advanced
        }

        # ---- 4. Costs and health of this month ----------------------------------
        # Each state contributes a twelfth of its yearly cost and utility in
        # proportion to the share of the cohort in it. Money and health count
        # for less the further in the future they are, which is what
        # discounting expresses: at a rate of 3%, what happens a year from now
        # is worth 1 / 1.03 of the same today.
        costs[cycle] <- (sum(cohort * state.costs) / CYCLES.PER.YEAR + screening.cost) * discount.factor
        utilities[cycle] <- sum(cohort * state.utilities) / CYCLES.PER.YEAR * discount.factor

        # ---- 5. What a registry sees this month -----------------------------
        # New diagnoses, by stage, and deaths from cancer, against the time the
        # people alive spend at risk: a twelfth of a year each.
        new.local <- new.local + cohort[['preclinical.local']] * transitions['preclinical.local', 'diagnosed.local']
        new.advanced <- new.advanced + cohort[['preclinical.advanced']] * transitions['preclinical.advanced', 'diagnosed.advanced']
        person.years[cycle] <- alive / CYCLES.PER.YEAR
        diagnoses[cycle] <- new.local + new.advanced
        local.diagnoses[cycle] <- new.local
        cancer.deaths[cycle] <- sum(cohort[1:5] * transitions[1:5, 'cancer.death'])

        # ---- 6. Move the cohort one month forward -----------------------------
        # Multiplying the shares by the matrix sends each share to where its row
        # says, which gives the shares at the start of next month.
        cohort <- drop(cohort %*% transitions)
        cohort.trace[[cycle + 1]] <- cohort
      }
    }

    # ---- Results of the strategy ----------------------------------------------
    # C is the average discounted cost per year and E the discounted
    # quality-adjusted life years (QALYs) accumulated over the whole horizon.
    summary <- rbind(summary, data.frame(strategy = strategy,
                                         C = sum(costs) / length(ages),
                                         E = sum(utilities)))

    # Registry figures per age group, as registries report them: incidence and
    # mortality per 100,000 person-years, and the percentage of the diagnoses
    # made at the local stage.
    by.group <- function(values) colSums(matrix(values, ncol = n.groups))
    group.person.years <- by.group(person.years)
    group.diagnoses <- by.group(diagnoses)
    incidence[[strategy]] <- 1e5 * group.diagnoses / group.person.years
    local.share[[strategy]] <- 100 * by.group(local.diagnoses) / group.diagnoses
    mortality[[strategy]] <- 1e5 * by.group(cancer.deaths) / group.person.years

    cohort.info[[strategy]] <- cohort.trace
  }

  list(summary = summary,
       incidence = incidence,
       local.share = local.share,
       mortality = mortality,
       cohort.info = cohort.info)
}
