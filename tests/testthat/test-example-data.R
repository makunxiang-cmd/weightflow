test_that("wfc_example contains only simulated package data", {
  data("wfc_example", package = "WFC", envir = environment())

  expect_true(exists("wfc_example"))
  expect_true(is.list(wfc_example))
  expect_true(all(c("sample", "population", "dims") %in% names(wfc_example)))
  expect_true(is.data.frame(wfc_example$sample))
  expect_true(is.data.frame(wfc_example$population))
  expect_s3_class(wfc_example$dims, "wf_dims")
  expect_false(any(grepl("source", names(wfc_example))))
})
