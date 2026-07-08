test_that("weightflow_example contains only simulated package data", {
  data("weightflow_example", package = "weightflow", envir = environment())

  expect_true(exists("weightflow_example"))
  expect_true(is.list(weightflow_example))
  expect_true(all(c("sample", "population", "dims") %in% names(weightflow_example)))
  expect_true(is.data.frame(weightflow_example$sample))
  expect_true(is.data.frame(weightflow_example$population))
  expect_s3_class(weightflow_example$dims, "wf_dims")
  expect_false(any(grepl("source", names(weightflow_example))))
})
