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

#' Calibrate weights by a linear or logit distance (engine behind wf_calibrate).
#'
#' @param sample Sample data frame.
#' @param target A `wf_target` object.
#' @param distance "linear" or "logit".
#' @param method Reported method label ("greg" or "logit").
#' @param bounds `c(L, U)` for logit.
#' @param init_weight Optional base-weight column.
#' @param na "drop" or "error".
#' @param id Optional id column.
#' @param tol Convergence tolerance.
#' @param max_iter Iteration cap.
#' @param precheck Run `wf_precheck()` first.
#' @keywords internal
#' @noRd
.wf_lincalibrate <- function(sample, target, distance, method,
                             bounds = NULL, init_weight = NULL,
                             na = c("drop", "error"), id = NULL,
                             tol = 1e-8, max_iter = 100, precheck = TRUE) {
  na <- match.arg(na)
  t0 <- Sys.time()

  if (precheck) {
    pc <- wf_precheck(sample, target, id = id, na = "drop")
    if (!pc$ok) {
      wf_abort(sprintf(
        "Precheck reports %d blocking issue(s). Inspect wf_precheck(sample, target) before calibrating.",
        sum(pc$issues$severity == "error")
      ), "wf_error_feasibility", list(precheck = pc))
    }
  }

  dvars <- target$dims
  for (d in dvars) {
    if (!d %in% names(sample)) {
      wf_abort(sprintf("Calibration dimension '%s' not found in sample.", d),
               "wf_error_schema", list(dim = d))
    }
  }

  na_mask <- rowSums(sapply(dvars, function(d) is.na(sample[[d]]))) > 0
  if (any(na_mask)) {
    if (na == "error") {
      wf_abort(sprintf("%d row(s) have NA in calibration dimensions.", sum(na_mask)),
               "wf_error_schema", list(n = sum(na_mask)))
    }
    wf_warn(sprintf("na='drop': removed %d row(s) with NA in calibration dimensions.",
                    sum(na_mask)), "wf_warning_data")
    sample <- sample[!na_mask, , drop = FALSE]
  }

  if (is.null(init_weight)) {
    iw <- rep(1, nrow(sample))
  } else {
    if (length(init_weight) != 1 || !is.character(init_weight) ||
        !init_weight %in% names(sample)) {
      wf_abort(sprintf("init_weight column '%s' not found in sample.",
                       as.character(init_weight)[1]),
               "wf_error_schema", list(init_weight = init_weight))
    }
    iw <- as.numeric(sample[[init_weight]])
    if (any(!is.finite(iw)) || any(iw < 0)) {
      wf_abort("init_weight must be non-negative and finite.",
               "wf_error_input", list(init_weight = init_weight))
    }
  }

  dist <- .wf_lincal_dist(distance, bounds)
  gkey <- .wf_group_keys(sample, target$by)
  ids <- if (is.null(id)) seq_len(nrow(sample)) else sample[[id]]

  res_rows <- list()
  logs <- list()
  achieved <- list()
  for (g in intersect(names(target$groups), unique(gkey))) {
    sel <- which(gkey == g)
    gr <- target$groups[[g]]
    sub <- sample[sel, , drop = FALSE]
    built <- .wf_lincal_build(sub, dvars, gr)
    fit <- .wf_lincal_group(built$X, iw[sel], built$t, dist,
                            tol, max_iter, gr$total, g)

    res_rows[[g]] <- data.frame(
      id = .chr(ids[sel]),
      group = g,
      weight = fit$w,
      feature = 1 / fit$w,
      stringsAsFactors = FALSE
    )
    logs[[g]] <- data.frame(
      group = g, n = length(sel), iterations = fit$iterations,
      converged = fit$converged, max_resid = fit$max_resid,
      ratio_min = min(fit$ratio), ratio_max = max(fit$ratio),
      stringsAsFactors = FALSE
    )
    achieved[[g]] <- lapply(dvars, function(d) {
      levs <- names(gr$margins[[d]])
      stats::setNames(
        vapply(levs, function(l) sum(fit$w[.chr(sub[[d]]) == l]), numeric(1)),
        levs
      )
    })
    names(achieved[[g]]) <- dvars
  }

  structure(list(
    data = do.call(rbind, res_rows),
    log = do.call(rbind, logs),
    achieved = achieved,
    provenance = list(
      method = method,
      distance = distance,
      bounds = bounds,
      init_weight = init_weight,
      na = na,
      dims = dvars,
      by = target$by,
      tol = tol,
      max_iter = max_iter,
      created = t0,
      elapsed = as.numeric(Sys.time() - t0, units = "secs"),
      package_version = .wf_lincal_package_version()
    )
  ), class = "wf_weights")
}
