test_that("wf_rake refuses blocked prechecks", {
  fixture <- make_weightflow_fixture()
  sample <- fixture$sample
  sample$gender[1] <- "other"

  expect_error(
    wf_rake(sample, fixture$target, id = "id"),
    class = "wf_error_feasibility"
  )
})

test_that("wf_rake returns positive weights matching target margins", {
  fixture <- make_weightflow_fixture()

  weights <- wf_rake(fixture$sample, fixture$target, id = "id", tol = 1e-8)

  expect_s3_class(weights, "wf_weights")
  expect_true(all(weights$data$weight > 0))
  expect_equal(sum(weights$data$weight[weights$data$group == "A"]), 200, tolerance = 1e-6)
  expect_equal(sum(weights$data$weight[weights$data$group == "B"]), 200, tolerance = 1e-6)

  for (group in names(fixture$target$groups)) {
    for (dim_name in fixture$target$dims) {
      expect_equal(
        weights$achieved[[group]][[dim_name]],
        fixture$target$groups[[group]]$margins[[dim_name]],
        tolerance = 1e-6
      )
    }
  }
})

test_that("wf_diagnose reports diagnostics and margin error", {
  fixture <- make_weightflow_fixture()
  weights <- wf_rake(fixture$sample, fixture$target, id = "id", tol = 1e-8)

  diag <- wf_diagnose(weights, target = fixture$target)

  expect_s3_class(diag, "wf_diagnostics")
  expect_true(all(c("ess", "deff", "verdict", "margin_maxerr") %in% names(diag$table)))
  expect_true(all(diag$table$margin_maxerr <= 1e-4))
})
