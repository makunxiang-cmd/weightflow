# AGENTS.md

## Project Authority

Follow `inst/design/weightflow_design.md` as the design authority and
`inst/reference/weightflow_core.R` as the 0.1.0 implementation reference.

## Language Policy

Use English for package code, tests, documentation, configuration, and commit
messages. The only Chinese-language repository file is `README.zh-CN.md`.

## Data Policy

Files under `private-data/` are local private source data. Do not commit them,
read them into examples, or include them in package builds. Package examples use
only simulated data generated from `data-raw/make-weightflow-example.R`.

## Development Policy

Use test-driven development for behavior changes. Run focused tests after each
change, then run the full package verification before claiming completion.

## Git Policy

Stage files intentionally. Do not add private source data, local build outputs,
`.codegraph/`, `.DS_Store`, or generated check directories.
