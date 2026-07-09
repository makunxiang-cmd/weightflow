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

test_that(".wf_boot_mult returns an n x R matrix with unit scale/rscales", {
  d <- make_design_data()
  des <- .wf_design(d, strata = "stratum", clusters = "psu")
  gen <- .wf_boot_mult(des, R = 50, seed = 1)

  expect_equal(dim(gen$mult), c(8, 50))
  expect_equal(gen$scale, 1 / 50)
  expect_equal(gen$rscales, rep(1, 50))
  expect_true(all(gen$mult >= 0))
})

test_that(".wf_boot_mult multipliers are constant within a PSU", {
  d <- make_design_data()
  des <- .wf_design(d, strata = "stratum", clusters = "psu")
  gen <- .wf_boot_mult(des, R = 10, seed = 1)
  # rows 1,2 are PSU a1; rows 3,4 are PSU a2
  expect_equal(gen$mult[1, ], gen$mult[2, ])
  expect_equal(gen$mult[3, ], gen$mult[4, ])
})

test_that(".wf_boot_mult per-stratum multiplier mean is about 1", {
  d <- make_design_data()
  des <- .wf_design(d, strata = "stratum", clusters = "psu")
  gen <- .wf_boot_mult(des, R = 4000, seed = 42)
  stratum_A <- colMeans(gen$mult[1:4, ])  # 2 PSUs x 2 units, mean over units per rep
  expect_equal(mean(stratum_A), 1, tolerance = 0.05)
})

test_that(".wf_boot_mult is reproducible with a seed", {
  d <- make_design_data()
  des <- .wf_design(d, strata = "stratum", clusters = "psu")
  g1 <- .wf_boot_mult(des, R = 20, seed = 7)
  g2 <- .wf_boot_mult(des, R = 20, seed = 7)
  expect_identical(g1$mult, g2$mult)
})
