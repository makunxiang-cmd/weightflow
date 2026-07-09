# weightflow

<!-- badges: start -->
[![Project Status: WIP](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![R >= 3.5.0](https://img.shields.io/badge/R-%3E%3D%203.5.0-blue.svg)](https://cran.r-project.org/)
<!-- badges: end -->

**English** | [Simplified Chinese](README.zh-CN.md)

`weightflow` is a workflow-oriented R package for survey weighting and raking. It
emphasizes a disciplined **precheck → execute → diagnose** loop for multi-source
survey calibration, with schema-agnostic dimensions and canonical target objects
that stay consistent across raking and post-stratification engines.

## Why weightflow

Most weighting scripts fail silently: a category is missing from the target, a
cell is too thin to estimate, or a group total drifts after trimming. `weightflow`
turns those failure modes into first-class, reviewable steps.

- **Precheck before you calibrate.** `wf_precheck()` compares the sample against
  the target and reports incompatibilities before any weights are computed.
- **One target contract, many sources.** Build a canonical `wf_target` from
  external population data, a weighted reference sample, or a manual margin table.
- **Reviewable category collapsing.** Declare a collapse ladder up front, get
  suggested merges from precheck findings, and apply them consistently to both
  sample and target.
- **Raking and post-stratification behind one dispatcher.** `wf_calibrate()`
  returns the same `wf_weights` contract regardless of method.
- **Diagnostics as a habit.** `wf_diagnose()` closes every workflow with weight
  and margin diagnostics.

## Installation

Install the development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("makunxiang-cmd/weightflow")
```

Or build from a source tarball:

```r
install.packages("weightflow_0.5.0.tar.gz", repos = NULL, type = "source")
```

## Workflow at a glance

```
declare dims ──► build target ──► precheck ──► (collapse) ──► calibrate ──► diagnose
   wf_dims()      wf_target_*()   wf_precheck()  wf_suggest_    wf_rake() /   wf_diagnose()
                                                 collapse()     wf_poststrat()
                                                 wf_apply_      wf_calibrate()
                                                 collapse()
```

## Quick start

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

## Post-stratification

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

## Foundation API

Manual margins can be converted directly to a target and calibrated through the
unified dispatcher. A target can also be shrunk toward a reference target before
calibration.

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

## Pipeline Ledger

Multiple weighting stages can be composed into one auditable `wf_weights` object.
Composition matches units by ID, multiplies stage weights, and stores each stage
in provenance.

```r
calibration <- wf_rake(weightflow_example$sample, target, id = "id")

adjustment <- calibration
adjustment$data$weight <- rep(c(0.9, 1.1), length.out = nrow(adjustment$data))
adjustment$data$feature <- 1 / adjustment$data$weight
adjustment$provenance$method <- "nonresponse_adjustment_example"

final_weights <- wf_compose(adjustment, calibration, normalize = "mean1")
wf_diagnose(final_weights)
```

## Dual-Source Fusion

Online and offline calibrated sources can be fused at the estimator level with
`wf_blend()`. The function computes each source's cell estimate first, then
combines those estimates with the applied lambda recorded in the result.

```r
online <- wf_rake(weightflow_example$sample, target, id = "id")
offline <- online

analysis_cols <- weightflow_example$sample[c("id", "gender", "age")]
online$data <- merge(online$data, analysis_cols, by = "id", all.x = TRUE, sort = FALSE)
offline$data <- merge(offline$data, analysis_cols, by = "id", all.x = TRUE, sort = FALSE)

online$data$cell <- online$data$gender
offline$data$cell <- offline$data$gender
online$data$outcome <- as.numeric(online$data$age == "young")
offline$data$outcome <- as.numeric(offline$data$age == "young")

blend <- wf_blend(
  online,
  offline,
  by_cell = "cell",
  outcome = "outcome",
  lambda = "neff"
)

blend$estimates
blend$lambda
```

## Function reference

| Stage | Function | Purpose |
| --- | --- | --- |
| Dimensions | `wf_dims()` | Declare calibration dimensions and optional collapse ladders. |
| Target | `wf_target_population()` | Build a canonical target from external population data. |
| Target | `wf_target_reference()` | Build a target from a weighted reference sample. |
| Target | `wf_target_manual()` | Build a target from a manual long margin table. |
| Target | `wf_target_shrink()` | Shrink a target toward a reference target. |
| Precheck | `wf_precheck()` | Check sample/target compatibility before calibration. |
| Collapse | `wf_collapse_ladder()` | Declare a post-stratification collapse ladder. |
| Collapse | `wf_suggest_collapse()` | Suggest collapse plans from precheck findings. |
| Collapse | `wf_apply_collapse()` | Apply a collapse plan to sample and target. |
| Calibrate | `wf_calibrate()` | Dispatch to a calibration method (raking or post-strat). |
| Calibrate | `wf_rake()` | Grouped raking (iterative proportional fitting). |
| Calibrate | `wf_plan_poststrat()` | Plan post-stratification cell resolution. |
| Calibrate | `wf_poststrat()` | Run cell-level post-stratification. |
| Compose | `wf_compose()` | Compose multiple weighting stages into one auditable result. |
| Fusion | `wf_blend()` | Fuse online and offline estimates at the estimator level. |
| Diagnose | `wf_diagnose()` | Diagnose calibrated weights and margins. |

All exported functions ship with full documentation. From R, use `?wf_rake`,
`help(package = "weightflow")`, or `example(wf_target_population)`.

## Data policy

Private source spreadsheets and RData files under `private-data/` are **not
committed** and are **not** included in package builds. All examples and tests use
the simulated `weightflow_example` dataset, generated by
`data-raw/make-weightflow-example.R`.

## Project status

This repository is in the foundation API build stage. The 0.3.0 scope adds manual
targets, target shrinkage, collapse suggestions, collapse-plan application, and
unified calibration dispatch while preserving the existing raking and
post-stratification engines. See [`NEWS.md`](NEWS.md) for the full changelog.

## Contributing

Contributions are welcome. Please read
[`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) for development setup, the
test-driven workflow, and the language policy, and review the
[Code of Conduct](.github/CODE_OF_CONDUCT.md) before opening an issue or pull
request. Repository conventions for automated agents are documented in
[`AGENTS.md`](AGENTS.md).

## License

Released under the [MIT License](LICENSE.md). © 2026 makunxiang-cmd and weightflow
contributors.
