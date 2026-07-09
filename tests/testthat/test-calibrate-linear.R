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
