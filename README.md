# weightflow

`weightflow` is a workflow-oriented R package for survey weighting and raking.
It emphasizes a disciplined precheck -> execute -> diagnose loop for
multi-source survey calibration.

## Status

This repository is in the foundation API build stage. The 0.3.0 scope adds
manual targets, target shrinkage, collapse suggestions, collapse-plan
application, and unified calibration dispatch while preserving the existing
raking and post-stratification engines.

## Data Policy

Private source spreadsheets and RData files are not committed and are not
included in package builds. Examples use the simulated `weightflow_example`
dataset.

## Minimal Example

```r
library(weightflow)

data(weightflow_example)

dims <- weightflow_example$dims
target <- wf_target_population(
  pop = weightflow_example$population,
  key_map = c(gender = "gender", age = "age"),
  count = "count",
  dims = dims,
  by = "province"
)

precheck <- wf_precheck(weightflow_example$sample, target, id = "id")
precheck

weights <- wf_rake(weightflow_example$sample, target, id = "id")
wf_diagnose(weights, target = target)
```

## Post-Stratification Example

Post-stratification uses joint population cells instead of marginal totals. Build
the target with `keep_joint = TRUE`, declare a reviewable collapse ladder, then
plan and execute the cell calibration.

```r
target_joint <- wf_target_population(
  pop = weightflow_example$population,
  key_map = c(gender = "gender", age = "age"),
  count = "count",
  dims = dims,
  by = "province",
  keep_joint = TRUE
)

ladder <- wf_collapse_ladder(
  dims,
  level1 = list(age = c(young = "all", old = "all"))
)

plan <- wf_plan_poststrat(
  weightflow_example$sample,
  target_joint,
  min_cell = 2,
  ladder = ladder
)
plan

post <- wf_poststrat(
  weightflow_example$sample,
  target_joint,
  min_cell = 2,
  ladder = ladder,
  id = "id"
)
wf_diagnose(post)
```

## Foundation API Example

Manual margins can be converted directly to a target and then calibrated through
the unified dispatcher.

```r
manual <- data.frame(
  dimension = c("gender", "gender", "age", "age"),
  category = c("female", "male", "young", "old"),
  value = c(55, 45, 60, 40)
)

target_manual <- wf_target_manual(manual, dims)
weights_manual <- wf_calibrate(
  weightflow_example$sample,
  target_manual,
  method = "raking",
  id = "id"
)
wf_diagnose(weights_manual)
```
