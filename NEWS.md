# weightflow 0.6.0

Non-probability correction via propensity. Adds a two-step propensity workflow
that corrects a self-selected online sample against an offline probability
reference, emitting pseudo-design weights that feed calibration as initial
weights.

* Added `wf_target_propensity()` to stack an online sample and a probability
  reference into a membership-model specification.
* Added `wf_propensity()` to fit a base-R logistic membership model and emit
  inverse-propensity pseudo-design weights as a `wf_weights` stage, with
  stabilized IPW on by default and optional trimming.
* Added overlap / common-support and covariate-balance diagnostics, with a
  `wf_warning_quality` on poor support.

# weightflow 0.5.0

Dual-source fusion. Adds estimator-level online/offline fusion without stacking
row-level weights.

* Added `wf_blend()` for estimator-level dual-source fusion of online and
  offline `wf_weights` objects.
* Added `wf_blend_result` with source estimates, applied lambda values,
  diagnostics, sensitivity output, and provenance.
* Added support for `neff`, `inverse_variance`, and `fixed` lambda strategies.

# weightflow 0.4.0

Weight pipeline ledger. Adds a composition layer for chaining weighting stages
while preserving stage-level provenance.

* Added `wf_compose()` to multiply compatible `wf_weights` stages into one
  auditable `wf_weights` result.
* Added ID-safe composition with classed errors for duplicate IDs, missing IDs,
  different ID sets, incompatible groups, and invalid weights.
* Added optional composed-weight normalization with `normalize = "mean1"` and
  `normalize = "sum"`.

# weightflow 0.3.0

Foundation API completion. Extends the calibration workflow with manual targets,
target shrinkage, and a unified dispatcher, while preserving the existing raking
and post-stratification engines.

* Added `wf_target_manual()` to build a canonical target from a ready-made long
  margin table.
* Added `wf_target_shrink()` to shrink a target toward a reference target.
* Added `wf_suggest_collapse()` to turn precheck findings into a reviewable
  collapse plan using ladders declared in `wf_dims()`.
* Added `wf_apply_collapse()` to apply a collapse plan consistently to both the
  sample and the target.
* Added `wf_calibrate()`, a unified dispatcher that routes to `wf_rake()` or
  `wf_poststrat()` while preserving the common `wf_weights` contract.

# weightflow 0.2.0

Post-stratification engine. Adds cell-level calibration against joint population
targets, with reviewable collapse ladders and planning.

* Added joint population targets via `wf_target_population(..., keep_joint = TRUE)`.
* Added `wf_collapse_ladder()` to declare post-stratification collapse ladders.
* Added `wf_plan_poststrat()` to plan cell resolution before execution.
* Added `wf_poststrat()` to run cell-level post-stratification, returning a
  `cell_report` and `collapse_map`.

# weightflow 0.1.0

Initial package foundation and core raking workflow.

* Added `wf_dims()` to declare schema-agnostic calibration dimensions.
* Added `wf_target_population()` and `wf_target_reference()` target constructors.
* Added `wf_precheck()` for structured sample/target compatibility checks.
* Added `wf_rake()` grouped raking (iterative proportional fitting) with trimming
  cycles and a missing-data policy.
* Added `wf_diagnose()` weight and margin diagnostics.
* Added the simulated `weightflow_example` dataset for examples and tests.
