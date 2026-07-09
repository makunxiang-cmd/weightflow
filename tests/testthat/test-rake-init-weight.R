test_that("wf_rake init_weight = NULL reproduces the default result exactly", {
  fixture <- make_weightflow_fixture()
  a <- wf_rake(fixture$sample, fixture$target, id = "id")
  b <- wf_rake(fixture$sample, fixture$target, id = "id", init_weight = NULL)
  expect_equal(a$data$weight, b$data$weight)
})

test_that("wf_rake honors non-uniform init weights while matching margins", {
  fixture <- make_weightflow_fixture()
  s <- fixture$sample
  # Vary init WITHIN margin categories (young females only), so it is not
  # absorbed by the marginal gender/age calibration and actually shifts the
  # within-cell association.
  s$bw <- ifelse(s$gender == "female" & s$age == "young", 3, 1)

  uniform <- wf_rake(s, fixture$target, id = "id")
  weighted <- wf_rake(s, fixture$target, id = "id", init_weight = "bw")

  # init weights change the within-solution distribution
  expect_false(isTRUE(all.equal(uniform$data$weight, weighted$data$weight)))

  # but achieved gender totals still match (raking still hits its margins)
  female_uni <- sum(uniform$data$weight[s$gender == "female"])
  female_wtd <- sum(weighted$data$weight[s$gender == "female"])
  expect_equal(female_uni, female_wtd, tolerance = 1e-6)
})

test_that("wf_rake errors when init_weight column is missing", {
  fixture <- make_weightflow_fixture()
  expect_error(
    wf_rake(fixture$sample, fixture$target, id = "id", init_weight = "nope"),
    class = "wf_error_schema"
  )
})
