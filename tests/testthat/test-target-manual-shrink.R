test_that("manual target constructs canonical margins for one group", {
  dims <- wf_dims(gender = c("female", "male"), age = c("young", "old"))
  margins <- data.frame(
    dimension = c("gender", "gender", "age", "age"),
    category = c("female", "male", "young", "old"),
    value = c(60, 40, 55, 45),
    stringsAsFactors = FALSE
  )

  target <- wf_target_manual(margins, dims)

  expect_s3_class(target, "wf_target")
  expect_equal(target$mode, "manual")
  expect_null(target$by)
  expect_equal(names(target$groups), "_all_")
  expect_equal(target$groups$`_all_`$total, 100)
  expect_equal(target$groups$`_all_`$margins$gender, c(female = 60, male = 40))
  expect_equal(target$groups$`_all_`$margins$age, c(young = 55, old = 45))
})

test_that("manual target constructs grouped targets with explicit totals", {
  dims <- wf_dims(gender = c("female", "male"))
  margins <- data.frame(
    province = c("A", "A", "B", "B"),
    dimension = "gender",
    category = c("female", "male", "female", "male"),
    value = c(60, 40, 30, 70),
    stringsAsFactors = FALSE
  )

  target <- wf_target_manual(
    margins,
    dims,
    by = "province",
    totals = c(A = 100, B = 100)
  )

  expect_equal(target$by, "province")
  expect_equal(names(target$groups), c("A", "B"))
  expect_equal(target$groups$B$margins$gender, c(female = 30, male = 70))
})

test_that("manual target rejects non-additive dimensions", {
  dims <- wf_dims(gender = c("female", "male"), age = c("young", "old"))
  margins <- data.frame(
    dimension = c("gender", "gender", "age", "age"),
    category = c("female", "male", "young", "old"),
    value = c(60, 40, 55, 40),
    stringsAsFactors = FALSE
  )

  expect_error(
    wf_target_manual(margins, dims),
    class = "wf_error_input"
  )
})
