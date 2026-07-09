#' Return the loaded package version for provenance.
#'
#' @keywords internal
#' @noRd
.wf_lincal_package_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("weightflow")),
    error = function(e) "0.8.0"
  )
}

#' Build a calibration distance object (weight-generating function and slope).
#'
#' @param distance "linear" (GREG) or "logit" (bounded).
#' @param bounds Two-element `c(L, U)` for logit; ignored for linear.
#' @keywords internal
#' @noRd
.wf_lincal_dist <- function(distance, bounds) {
  if (distance == "linear") {
    return(list(
      F = function(u) 1 + u,
      Fp = function(u) rep(1, length(u))
    ))
  }
  L <- bounds[1]
  U <- bounds[2]
  A <- (U - L) / ((1 - L) * (U - 1))
  list(
    F = function(u) {
      e <- exp(A * u)
      (L * (U - 1) + U * (1 - L) * e) / ((U - 1) + (1 - L) * e)
    },
    Fp = function(u) {
      e <- exp(A * u)
      (U - L)^2 * e / ((U - 1) + (1 - L) * e)^2
    }
  )
}

#' Build the calibration constraint matrix and target vector for one group.
#'
#' @param sub Group's (complete-case) sample subset.
#' @param dvars Calibration dimension names.
#' @param gr A target group: `list(total, margins)`.
#' @keywords internal
#' @noRd
.wf_lincal_build <- function(sub, dvars, gr) {
  n <- nrow(sub)
  cols <- list(rep(1, n))
  t <- gr$total
  for (d in dvars) {
    lev <- names(gr$margins[[d]])
    for (l in lev[-1]) {   # drop the first level as the reference
      cols[[length(cols) + 1]] <- as.numeric(.chr(sub[[d]]) == l)
      t <- c(t, gr$margins[[d]][[l]])
    }
  }
  list(X = do.call(cbind, cols), t = t)
}

#' Solve the calibration equations for one group by Newton iteration.
#'
#' @param X Constraint matrix (n x p).
#' @param d Base weights (length n).
#' @param t Target totals (length p; `t[1]` is the group total).
#' @param dist A `.wf_lincal_dist()` object.
#' @param tol Convergence tolerance on the max residual relative to `total`.
#' @param max_iter Iteration cap.
#' @param total Group total (for the relative residual).
#' @param g Group label (for error messages).
#' @keywords internal
#' @noRd
.wf_lincal_group <- function(X, d, t, dist, tol, max_iter, total, g) {
  lambda <- rep(0, ncol(X))
  u <- as.numeric(X %*% lambda)
  w <- d * dist$F(u)
  steps <- 0L
  converged <- FALSE
  maxr <- NA_real_
  repeat {
    resid <- t - as.numeric(t(X) %*% w)
    maxr <- max(abs(resid)) / total
    if (maxr < tol) {
      converged <- TRUE
      break
    }
    if (steps >= max_iter) break
    jac <- t(X) %*% (X * (d * dist$Fp(u)))
    step <- tryCatch(solve(jac, resid), error = function(e) NULL)
    if (is.null(step)) {
      wf_abort(
        sprintf("Group '%s': singular calibration system (empty category or collinear margins).", g),
        "wf_error_feasibility", list(group = g)
      )
    }
    lambda <- lambda + step
    steps <- steps + 1L
    u <- as.numeric(X %*% lambda)
    w <- d * dist$F(u)
  }
  if (!converged) {
    wf_abort(
      sprintf("Group '%s': calibration did not converge in %d iterations (max relative residual %.3g). Bounds may be too tight to meet the margins.",
              g, max_iter, maxr),
      "wf_error_feasibility", list(group = g, residual = maxr)
    )
  }
  list(w = w, iterations = steps, converged = TRUE,
       max_resid = maxr, ratio = dist$F(u))
}
