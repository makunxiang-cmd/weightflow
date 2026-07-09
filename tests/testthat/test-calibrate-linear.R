test_that(".wf_lincal_dist linear gives F(u)=1+u and F'(u)=1", {
  dist <- .wf_lincal_dist("linear", NULL)
  u <- c(-0.5, 0, 0.5, 2)
  expect_equal(dist$F(u), 1 + u)
  expect_equal(dist$Fp(u), rep(1, length(u)))
})

test_that(".wf_lincal_dist logit maps to (L,U) with F(0)=1 and unit slope at 0", {
  L <- 0.3; U <- 3
  dist <- .wf_lincal_dist("logit", c(L, U))
  u <- seq(-10, 10, by = 0.5)
  fu <- dist$F(u)
  expect_true(all(fu > L & fu < U))
  expect_equal(dist$F(0), 1)
  expect_equal(dist$Fp(0), 1)          # slope at 0 matches the linear distance
})

test_that(".wf_lincal_dist logit F' matches a numeric derivative", {
  dist <- .wf_lincal_dist("logit", c(0.5, 4))
  u0 <- 0.7
  numeric <- (dist$F(u0 + 1e-6) - dist$F(u0 - 1e-6)) / (2e-6)
  expect_equal(dist$Fp(u0), numeric, tolerance = 1e-5)
})

test_that(".wf_lincal_build makes an intercept + dropped-reference-level matrix", {
  sub <- data.frame(g = c("a", "a", "b", "b"), stringsAsFactors = FALSE)
  gr <- list(total = 4, margins = list(g = c(a = 3, b = 1)))
  built <- .wf_lincal_build(sub, dvars = "g", gr = gr)

  # intercept column + one column for the retained level "b" (a is the ref)
  expect_equal(ncol(built$X), 2)
  expect_equal(built$X[, 1], rep(1, 4))
  expect_equal(built$X[, 2], c(0, 0, 1, 1))
  expect_equal(built$t, c(4, 1))          # total, then b's margin
})

test_that(".wf_lincal_build stacks multiple dims, dropping one level each", {
  sub <- data.frame(
    g = c("a", "b", "a", "b"),
    h = c("x", "x", "y", "y"),
    stringsAsFactors = FALSE
  )
  gr <- list(total = 4,
             margins = list(g = c(a = 2, b = 2), h = c(x = 2, y = 2)))
  built <- .wf_lincal_build(sub, dvars = c("g", "h"), gr = gr)
  # intercept + (g: drop a, keep b) + (h: drop x, keep y) = 3 columns
  expect_equal(ncol(built$X), 3)
  expect_equal(built$t, c(4, 2, 2))
})

test_that(".wf_lincal_group solves the GREG closed form by hand", {
  # sample a,a,b,b; base 1; total 4; margin a=3,b=1 -> weights 1.5,1.5,0.5,0.5
  X <- cbind(rep(1, 4), c(0, 0, 1, 1))
  t <- c(4, 1)
  d <- rep(1, 4)
  dist <- .wf_lincal_dist("linear", NULL)
  out <- .wf_lincal_group(X, d, t, dist, tol = 1e-10, max_iter = 100,
                          total = 4, g = "_all_")

  expect_true(out$converged)
  expect_equal(out$w, c(1.5, 1.5, 0.5, 0.5))
  expect_equal(out$iterations, 1)          # linear converges in one step
})

test_that(".wf_lincal_group logit keeps ratios within bounds and hits the target", {
  X <- cbind(rep(1, 4), c(0, 0, 1, 1))
  t <- c(4, 1)
  d <- rep(1, 4)
  dist <- .wf_lincal_dist("logit", c(0.3, 3))
  out <- .wf_lincal_group(X, d, t, dist, tol = 1e-10, max_iter = 100,
                          total = 4, g = "_all_")

  expect_true(out$converged)
  expect_true(all(out$ratio > 0.3 & out$ratio < 3))
  # margins: intercept and category-b constraint both met
  expect_equal(sum(out$w), 4, tolerance = 1e-8)
  expect_equal(sum(out$w[3:4]), 1, tolerance = 1e-8)
})

test_that(".wf_lincal_group aborts when bounds are infeasible", {
  # b units need mean 0.5 but a floor of 0.6 makes sum >= 1.2 > 1: infeasible
  X <- cbind(rep(1, 4), c(0, 0, 1, 1))
  t <- c(4, 1)
  d <- rep(1, 4)
  dist <- .wf_lincal_dist("logit", c(0.6, 3))
  expect_error(
    .wf_lincal_group(X, d, t, dist, tol = 1e-10, max_iter = 50,
                     total = 4, g = "_all_"),
    class = "wf_error_feasibility"
  )
})
