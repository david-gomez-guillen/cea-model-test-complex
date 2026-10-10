# Test model with a hidden natural history

A cost-effectiveness model of a hypothetical cancer, used as a test bed for
calibration methods. It compares doing nothing against a screening programme and
against treating diagnosed cases, over the lifetime of a single cohort.

Its calibration is deliberately hard in one specific way: it is badly
conditioned. The targets pin some combinations of the parameters down to a
fraction of a percent and say almost nothing about others, so a good fit
depends on getting many values right together, to three or four significant
digits.

## Model structure

The model is a seven-state Markov cohort model with monthly cycles:

- **Healthy**: alive and cancer-free. The whole cohort starts here.
- **Preclinical local** and **Preclinical advanced**: a cancer nobody knows about
  yet. It causes no symptoms, costs nothing and takes no health away. A local one
  can grow into an advanced one.
- **Diagnosed local** and **Diagnosed advanced**: a cancer diagnosed at that stage,
  either because it caused symptoms or because screening found it.
- **Cancer death** and **Other death**: absorbing states. Only diagnosed cancers
  kill, a local one far less than an advanced one. Death from other causes is
  possible from every living state and grows exponentially with age (Gompertz).

The cohort is followed from age 30 to age 74 (540 cycles), with no new entries.
Parameters are annual probabilities. Each is converted into a hazard, and the
hazards out of a state compete within each month. Costs and utilities of a month
are accrued before the transitions are applied.

## Strategies

- **No intervention**: cancers are diagnosed only when they cause symptoms.
- **Screening**: everyone alive and undiagnosed is screened once a year. The test
  finds a share of the preclinical cancers, more of the advanced ones than of the
  local ones, which are then diagnosed at the stage they had reached.
- **Treatment**: every diagnosed person is treated, which lowers their hazard of
  dying of the cancer.

## Parameters

| Parameter | Base value | Class | Meaning |
|---|---|---|---|
| `p.onset` | 0.004 | Natural history | Annual probability of a preclinical cancer starting while healthy. One value per age group. |
| `p.progression` | 0.3 | Natural history | Annual probability of a preclinical local cancer becoming advanced. One value per age group. |
| `p.symptoms.local` | 0.05 | Natural history | Annual probability of a preclinical local cancer causing symptoms. |
| `p.symptoms.advanced` | 0.25 | Natural history | Annual probability of a preclinical advanced cancer causing symptoms. |
| `p.cancer.death` | 0.2 | Mortality | Annual probability of dying of a diagnosed advanced cancer. One value per age group. |
| `rr.cancer.death.local` | 0.08 | Mortality | Hazard of dying of a diagnosed local cancer, relative to an advanced one. |
| `p.other.death` | 0.0008 | Mortality | Annual probability of dying of other causes at age 30. |
| `other.death.growth` | 0.085 | Mortality | Yearly growth of the hazard of dying of other causes. |
| `screening.sensitivity.local` | 0.55 | Screening | Share of the preclinical local cancers a screen finds. |
| `screening.sensitivity.advanced` | 0.85 | Screening | Share of the preclinical advanced cancers a screen finds. |
| `cost.screening` | 150 | Screening | Cost of one screening test. |
| `hr.treatment` | 0.7 | Treatment | Hazard ratio of cancer death under `treatment`. |
| `cost.treatment` | 30000 | Treatment | Annual cost of treatment per diagnosed person. |
| `cost.care.local` | 5000 | General | Annual cost of usual care of a diagnosed local cancer. |
| `cost.care.advanced` | 25000 | General | Annual cost of usual care of a diagnosed advanced cancer. |
| `utility.local` | 0.85 | General | Utility of a year lived with a diagnosed local cancer. |
| `utility.advanced` | 0.55 | General | Utility of a year lived with a diagnosed advanced cancer. |
| `discount` | 0.03 | General | Discount rate. |

The class is only used to group the parameters in the interface. The base values
of the three parameters given per age group are flat, the same at every age.

## Strata

Results are reported by five-year age group, from 30-34 to 70-74.

## Outputs

- `summary`: one row per strategy with the cost (`C`, the mean discounted cost per
  year) and the effect (`E`, the discounted quality-adjusted life years accumulated
  over the whole horizon).
- `incidence`: new diagnoses per 100,000 person-years lived in each age group.
- `local.share`: percentage of the diagnoses of each age group made at the local stage.
- `mortality`: cancer deaths per 100,000 person-years lived in each age group.

These three are what a cancer registry reports, and the only things the
calibration sees: none of the preclinical states is observed.

## Calibration

There are three schemes, of increasing difficulty. Each one calibrates one or
more of the parameters given per age group, nine values each, using the
`no_intervention` strategy. Each starts from the flat base values and holds every
other parameter at its base value.

| Scheme | Calibrates | Targets | Values |
|---|---|---|---|
| `incidence` | `p.onset` | Cancer incidence | 9 against 9 |
| `natural_history` | `p.onset`, `p.progression` | Cancer incidence, Local stage share | 18 against 18 |
| `full` | `p.onset`, `p.progression`, `p.cancer.death` | Cancer incidence, Local stage share, Cancer mortality | 27 against 27 |

The targets were generated by running the model on a hidden set of true
parameter values. Each scheme has its own targets, generated with only its own
parameters away from their base values. Every scheme can therefore be fitted
exactly, and its minimum error is 0.

The error is a chi-square: the sum, over every target and age group, of the
squared difference between the simulated and the target value, in standard
errors of the target. The standard error is 0.5% of the value for incidence, 1%
for mortality, and 1 percentage point for the local stage share. A fit within one
standard error everywhere scores about the number of targets. Parameter sets that
make the simulation fail get an infinite error.

### Why it is hard

- **Incidence is a blurred image of onset.** A cancer stays preclinical for about
  five years on average before it causes symptoms. So the diagnoses of an age
  group come from onsets spread over that group and the one or two before it.
  Recovering onset from incidence is a deconvolution, which amplifies errors. Two
  neighbouring age groups can trade onset almost freely: raising one and lowering
  the next barely changes the targets, while raising both shifts them a lot.
- **No target belongs to one parameter.** Incidence depends on onset and on
  progression, since advanced cancers cause symptoms sooner. The stage share
  depends on progression and on the onset history. Mortality depends on all
  three, through the number of advanced cases. The bias of a target does not say
  which parameter to move.
- **The oldest age groups are barely observed.** A cancer starting at 72 is
  usually diagnosed after 74, so the onset of the last age group is seen only
  through the few cases diagnosed in the same group.
- **Monthly cycles compound small errors.** A relative error in a monthly
  probability is applied 540 times.

At the true values, the condition number of the Hessian of the error, in the unit
cube of the search box, is about 1e5 for `incidence`, 3e5 for `natural_history`
and 4e5 for `full`. Reaching a chi-square of 1 takes a precision of about 0.4%
along the stiffest combination of parameters. The weakest combinations are
oscillations between neighbouring age groups, mostly the oldest ones.
`tests/difficulty.R` measures all of this.

### Latent space training set

The training set encodes what is known about the shape of the solution, not the
solution itself. Each profile is smooth in age: it is drawn by picking, at
random, its distance from the initial guess at the youngest, middle and oldest
age groups, on a log scale, and joining the three by a parabola. Values are kept
within the search box and below 1. Each calibrated parameter therefore
contributes three degrees of freedom, so 3, 6 and 9 latent dimensions are the
natural sizes for the three schemes.

The true profiles are smooth, but not all of them belong to that family: the
progression profile is logistic. Within the family, the lowest error reachable is
about 0 for `incidence`, 7 for `natural_history` and 8 for `full`. That is a good
fit, but not the exact one. Going below it means leaving the latent space and
refining in the full parameter space.

`generate.training.dataset.independent()` draws every value on its own instead,
as a model that knows nothing about the shape of the profiles would. No scheme
uses it; it is there for comparison.
