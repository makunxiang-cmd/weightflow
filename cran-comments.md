## Test environments

* Local: macOS Tahoe 26.5.1, R 4.6.0 (aarch64-apple-darwin23)
* GitHub Actions: R devel, release, and oldrel-1 on Linux; R release on
  macOS and Windows

## R CMD check results

Local `R CMD check --as-cran --no-manual`:

* 0 errors
* 0 warnings
* 1 note

The note identifies WFC as a new submission and lists the maintainer. There are
no downstream dependencies because this is a first submission.

## Additional verification

* The test suite includes an optional numerical oracle against `survey::rake()`.
* CI enforces at least 80% line coverage.
* Usability plot methods are exercised on non-interactive PDF devices, and the
  report suite verifies Markdown, escaped standalone HTML, and file output.
* Package examples and vignettes use only the bundled simulated `wfc_example`
  data. Files under `private-data/` are excluded from builds and are never read
  by examples or tests.
