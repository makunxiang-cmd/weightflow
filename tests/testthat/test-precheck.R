test_that("precheck reports unknown sample categories", {
  fixture <- make_weightflow_fixture()
  sample <- fixture$sample
  sample$gender[1] <- "other"

  pc <- wf_precheck(sample, fixture$target, id = "id")

  expect_false(pc$ok)
  expect_true("cat_unknown_in_sample" %in% pc$issues$check)
})

test_that("precheck reports infeasible positive target cells", {
  fixture <- make_weightflow_fixture()
  sample <- subset(fixture$sample, !(province == "B" & gender == "male"))

  pc <- wf_precheck(sample, fixture$target, id = "id", na = "drop")

  expect_false(pc$ok)
  expect_true("cat_infeasible" %in% pc$issues$check)
})

test_that("precheck reports duplicate ids", {
  fixture <- make_weightflow_fixture()
  sample <- fixture$sample
  sample$id[2] <- sample$id[1]

  pc <- wf_precheck(sample, fixture$target, id = "id")

  expect_false(pc$ok)
  expect_true("dup_id" %in% pc$issues$check)
})

test_that("precheck reports overloaded missing dimensions", {
  fixture <- make_weightflow_fixture()
  sample <- fixture$sample
  sample$gender[1] <- NA
  sample$age[1] <- NA

  pc <- wf_precheck(sample, fixture$target, id = "id", max_na_dims = 1)

  expect_false(pc$ok)
  expect_true("na_overload" %in% pc$issues$check)
})
