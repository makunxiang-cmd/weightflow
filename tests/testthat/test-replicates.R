make_design_data <- function() {
  data.frame(
    id = paste0("u", 1:8),
    stratum = c("A", "A", "A", "A", "B", "B", "B", "B"),
    psu = c("a1", "a1", "a2", "a2", "b1", "b1", "b2", "b2"),
    y = c(1, 0, 1, 1, 0, 0, 1, 0),
    stringsAsFactors = FALSE
  )
}

test_that(".wf_design resolves strata and clusters", {
  d <- make_design_data()
  des <- .wf_design(d, strata = "stratum", clusters = "psu")
  expect_equal(des$n, 8)
  expect_setequal(des$strata, c("A", "B"))
  expect_setequal(des$psu[["A"]], c("a1", "a2"))
})

test_that(".wf_design defaults each row to its own PSU and a single stratum", {
  d <- make_design_data()
  des <- .wf_design(d, strata = NULL, clusters = NULL)
  expect_equal(des$strata, "1")
  expect_equal(length(des$psu[["1"]]), 8)
})

test_that(".wf_design rejects clusters that span strata", {
  d <- make_design_data()
  d$psu[5] <- "a1"  # a1 now appears in both stratum A and B
  expect_error(
    .wf_design(d, strata = "stratum", clusters = "psu"),
    class = "wf_error_design"
  )
})

test_that(".wf_design rejects missing columns", {
  d <- make_design_data()
  expect_error(.wf_design(d, strata = "nope", clusters = NULL),
               class = "wf_error_input")
})
