#' Normalize calibration keys to trimmed character values.
#'
#' @param x Vector to normalize.
#' @return A character vector.
#' @keywords internal
.chr <- function(x) {
  trimws(as.character(x))
}

#' Require columns in a data frame.
#'
#' @param df Data frame to check.
#' @param cols Required column names.
#' @param what Human-readable data source name.
#' @keywords internal
.require_cols <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0) {
    wf_abort(sprintf(
      "%s is missing column(s): %s",
      what,
      paste(miss, collapse = ", ")
    ), "wf_error_schema", list(missing = miss))
  }
}

#' Create a validated target object.
#'
#' @param mode Target mode.
#' @param by Grouping variable.
#' @param dims Dimension names.
#' @param groups Target groups.
#' @param meta Provenance metadata.
#' @keywords internal
.wf_new_target <- function(mode, by, dims, groups, meta = list()) {
  tgt <- structure(
    list(mode = mode, by = by, dims = dims, groups = groups, meta = meta),
    class = "wf_target"
  )
  .wf_validate_target(tgt)
  tgt
}

#' Validate target invariants.
#'
#' @param tgt Target object.
#' @param tol Relative tolerance.
#' @keywords internal
.wf_validate_target <- function(tgt, tol = 1e-8) {
  for (g in names(tgt$groups)) {
    gr <- tgt$groups[[g]]
    if (!is.finite(gr$total) || gr$total <= 0) {
      wf_abort(sprintf(
        "Group '%s': target total must be positive and finite.",
        g
      ), "wf_error_input", list(group = g, total = gr$total))
    }
    for (d in tgt$dims) {
      m <- gr$margins[[d]]
      if (is.null(m) || is.null(names(m))) {
        wf_abort(sprintf(
          "Group '%s', dim '%s': margins missing or unnamed.",
          g,
          d
        ), "wf_error_internal", list(group = g, dim = d))
      }
      if (any(!is.finite(m)) || any(m < 0)) {
        wf_abort(sprintf(
          "Group '%s', dim '%s': margins must be finite and >= 0.",
          g,
          d
        ), "wf_error_input", list(group = g, dim = d))
      }
      if (abs(sum(m) - gr$total) > tol * gr$total) {
        wf_abort(sprintf(
          "Group '%s', dim '%s': margins sum to %.6g but total is %.6g. %s",
          g,
          d,
          sum(m),
          gr$total,
          "Additivity is required so IPF preserves the group total."
        ), "wf_error_input", list(group = g, dim = d))
      }
    }
  }
  invisible(TRUE)
}

#' Resolve group keys.
#'
#' @param df Data frame.
#' @param by Grouping variable name or `NULL`.
#' @param by_key Optional group key column or function.
#' @keywords internal
.wf_group_keys <- function(df, by, by_key = NULL) {
  if (!is.null(by_key)) {
    if (is.function(by_key)) {
      return(.chr(by_key(df)))
    }
    .require_cols(df, by_key, "population data")
    return(.chr(df[[by_key]]))
  }
  if (is.null(by)) {
    return(rep("_all_", nrow(df)))
  }
  .require_cols(df, by, "data")
  .chr(df[[by]])
}

#' Rescale target groups.
#'
#' @param groups Target group list.
#' @param scale Scale mode.
#' @param sample_n Per-group sample sizes.
#' @param totals Custom totals.
#' @keywords internal
.wf_scale_groups <- function(groups, scale, sample_n = NULL, totals = NULL) {
  if (scale == "population") {
    return(groups)
  }
  for (g in names(groups)) {
    new_total <-
      if (scale == "sample") {
        if (is.null(sample_n) || is.na(sample_n[g])) {
          wf_abort(sprintf(
            "scale='sample' needs the sample: no size found for group '%s'.",
            g
          ), "wf_error_input", list(group = g))
        }
        sample_n[g]
      } else {
        if (is.null(totals) || is.na(totals[g])) {
          wf_abort(sprintf(
            "scale='custom' requires totals['%s'].",
            g
          ), "wf_error_input", list(group = g))
        }
        totals[g]
      }
    f <- new_total / groups[[g]]$total
    groups[[g]]$total <- unname(new_total)
    groups[[g]]$margins <- lapply(groups[[g]]$margins, function(m) m * f)
  }
  groups
}

#' Sum weights by integer group index.
#'
#' @param w Weight vector.
#' @param idx Integer group indices.
#' @param K Number of groups.
#' @keywords internal
.grp_sum <- function(w, idx, K) {
  out <- numeric(K)
  rs <- rowsum(w, idx)
  out[as.integer(rownames(rs))] <- rs[, 1]
  out
}
