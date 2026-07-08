# weightflow

`weightflow` is a workflow-oriented R package for survey weighting and raking.
It emphasizes a disciplined precheck -> execute -> diagnose loop for
multi-source survey calibration.

## Status

This repository is in the first package build stage. The 0.1.0 scope is the
base-R raking workflow described in `inst/design/weightflow_design.md`.

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
