make_prop_frames <- function() {
  online <- data.frame(
    pid = paste0("o", 1:6),
    age = c(20, 25, 30, 35, 40, 45),
    edu = c("hs", "hs", "col", "col", "hs", "col"),
    stringsAsFactors = FALSE
  )
  reference <- data.frame(
    pid = paste0("r", 1:6),
    age = c(22, 33, 44, 55, 60, 28),
    edu = c("col", "col", "hs", "hs", "col", "hs"),
    stringsAsFactors = FALSE
  )
  list(online = online, reference = reference)
}

test_that("wf_target_propensity rejects a one-sided formula", {
  f <- make_prop_frames()
  expect_error(
    wf_target_propensity(f$online, f$reference, ~ age + edu),
    class = "wf_error_input"
  )
})

test_that("wf_target_propensity rejects an empty right-hand side", {
  f <- make_prop_frames()
  expect_error(
    wf_target_propensity(f$online, f$reference, member ~ 1),
    class = "wf_error_input"
  )
})

test_that("wf_target_propensity errors when a predictor is missing", {
  f <- make_prop_frames()
  expect_error(
    wf_target_propensity(f$online, f$reference, member ~ age + income),
    class = "wf_error_input"
  )
})

test_that("wf_target_propensity errors when membership name collides", {
  f <- make_prop_frames()
  expect_error(
    wf_target_propensity(f$online, f$reference, age ~ age + edu),
    class = "wf_error_input"
  )
})

test_that("wf_target_propensity errors on empty frames", {
  f <- make_prop_frames()
  expect_error(
    wf_target_propensity(f$online[0, ], f$reference, member ~ age),
    class = "wf_error_input"
  )
})
