#' Return the loaded package version for blend provenance.
#'
#' @keywords internal
#' @noRd
.wf_blend_package_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("weightflow")),
    error = function(e) "0.5.0"
  )
}

#' Validate one argument against allowed values without partial matching.
#'
#' @param value User-supplied scalar character value.
#' @param choices Supported values.
#' @param arg Argument name for error messages.
#' @keywords internal
#' @noRd
.wf_blend_match <- function(value, choices, arg) {
  if (length(value) == length(choices) && identical(value, choices)) {
    value <- value[[1]]
  }
  if (length(value) != 1 || is.na(value) || !value %in% choices) {
    shown <- if (length(value) == 0) "<empty>" else as.character(value[[1]])
    wf_abort(
      sprintf(
        "Unsupported %s '%s'. Supported values: %s.",
        arg,
        shown,
        paste(choices, collapse = ", ")
      ),
      "wf_error_input",
      stats::setNames(list(value), arg)
    )
  }
  value
}

#' Validate a blend cell variable vector.
#'
#' @param by_cell Requested cell columns.
#' @keywords internal
#' @noRd
.wf_blend_by_cell <- function(by_cell) {
  if (!is.character(by_cell) || length(by_cell) < 1 || any(is.na(by_cell)) || any(by_cell == "")) {
    wf_abort("`by_cell` must contain at least one non-empty column name.", "wf_error_input")
  }
  if (anyDuplicated(by_cell)) {
    wf_abort("`by_cell` must not contain duplicated column names.", "wf_error_input")
  }
  by_cell
}

#' Validate trim bounds for data-driven lambdas.
#'
#' @param trim_lambda Two finite bounds in increasing order.
#' @keywords internal
#' @noRd
.wf_blend_trim <- function(trim_lambda) {
  if (!is.numeric(trim_lambda) || length(trim_lambda) != 2 ||
    any(is.na(trim_lambda)) || any(!is.finite(trim_lambda)) ||
    trim_lambda[[1]] < 0 || trim_lambda[[2]] > 1 ||
    trim_lambda[[1]] > trim_lambda[[2]]) {
    wf_abort("`trim_lambda` must be two finite increasing values inside [0, 1].", "wf_error_input")
  }
  as.numeric(trim_lambda)
}

#' Validate one wf_weights source for blending.
#'
#' @param source Input object.
#' @param label Source label.
#' @param by_cell Cell columns.
#' @param outcome Optional outcome column.
#' @keywords internal
#' @noRd
.wf_blend_check_source <- function(source, label, by_cell, outcome) {
  if (!inherits(source, "wf_weights")) {
    wf_abort(
      sprintf("`%s` must be a wf_weights object.", label),
      "wf_error_input",
      list(source = label)
    )
  }
  if (!is.data.frame(source$data)) {
    wf_abort(
      sprintf("`%s$data` must be a data frame.", label),
      "wf_error_schema",
      list(source = label)
    )
  }

  required <- c("group", "weight", by_cell)
  if (!is.null(outcome)) {
    required <- c(required, outcome)
  }
  .require_cols(source$data, required, sprintf("%s$data", label))

  weight <- source$data$weight
  if (!is.numeric(weight) || any(is.na(weight)) || any(!is.finite(weight)) || any(weight < 0)) {
    wf_abort(
      sprintf("`%s$data$weight` must be finite, non-missing, and non-negative.", label),
      "wf_error_input",
      list(source = label)
    )
  }

  group <- .chr(source$data$group)
  if (any(is.na(group)) || any(group == "")) {
    wf_abort(
      sprintf("`%s$data$group` must not contain missing or empty values.", label),
      "wf_error_input",
      list(source = label)
    )
  }

  for (cell_col in by_cell) {
    cell_value <- .chr(source$data[[cell_col]])
    if (any(is.na(cell_value)) || any(cell_value == "")) {
      wf_abort(
        sprintf("`%s$data$%s` must not contain missing or empty values.", label, cell_col),
        "wf_error_input",
        list(source = label, column = cell_col)
      )
    }
  }

  if (!is.null(outcome)) {
    y <- source$data[[outcome]]
    if (!is.numeric(y) || all(is.na(y))) {
      wf_abort(
        sprintf("`%s$data$%s` must be numeric and not entirely missing.", label, outcome),
        "wf_error_input",
        list(source = label, outcome = outcome)
      )
    }
  }

  invisible(source)
}

#' Validate fixed lambda settings.
#'
#' @param lambda Strategy.
#' @param lambda_fixed User-supplied fixed lambda.
#' @keywords internal
#' @noRd
.wf_blend_check_fixed_required <- function(lambda, lambda_fixed) {
  if (lambda == "fixed" && is.null(lambda_fixed)) {
    wf_abort("`lambda_fixed` is required when `lambda = \"fixed\"`.", "wf_error_input")
  }
  invisible(lambda_fixed)
}

#' Build grouping keys for blend summaries.
#'
#' @param data Source data.
#' @param by_cell Cell columns.
#' @keywords internal
#' @noRd
.wf_blend_key <- function(data, by_cell) {
  key_data <- data.frame(group = .chr(data$group), stringsAsFactors = FALSE)
  for (cell_col in by_cell) {
    key_data[[cell_col]] <- .chr(data[[cell_col]])
  }
  .wf_cell_key(as.matrix(key_data), names(key_data))
}

#' Summarize one source by cell.
#'
#' @param source Source `wf_weights`.
#' @param label Source label.
#' @param by_cell Cell columns.
#' @param outcome Optional outcome column.
#' @keywords internal
#' @noRd
.wf_blend_source_cells <- function(source, label, by_cell, outcome) {
  data <- source$data
  key <- .wf_blend_key(data, by_cell)
  split_rows <- split(seq_len(nrow(data)), key)
  rows <- lapply(split_rows, function(idx) {
    part <- data[idx, , drop = FALSE]
    w_all <- as.numeric(part$weight)
    key_values <- data.frame(
      group = .chr(part$group[[1]]),
      stringsAsFactors = FALSE
    )
    for (cell_col in by_cell) {
      key_values[[cell_col]] <- .chr(part[[cell_col]][[1]])
    }

    if (is.null(outcome)) {
      estimate <- NA_real_
      variance <- NA_real_
      missing_outcome <- NA_integer_
      contributing <- w_all > 0
      w <- w_all[contributing]
    } else {
      y_all <- part[[outcome]]
      contributing <- w_all > 0 & !is.na(y_all)
      w <- w_all[contributing]
      y <- y_all[contributing]
      missing_outcome <- sum(is.na(y_all))
      if (length(w) > 0 && sum(w) > 0) {
        estimate <- sum(w * y) / sum(w)
        variance <- sum((w^2) * ((y - estimate)^2)) / (sum(w)^2)
      } else {
        estimate <- NA_real_
        variance <- NA_real_
      }
    }

    weight_sum <- sum(w)
    neff <- if (length(w) > 0 && sum(w^2) > 0) {
      (sum(w)^2) / sum(w^2)
    } else {
      0
    }

    cbind(
      key_values,
      data.frame(
        row_count = length(idx),
        weight_sum = weight_sum,
        neff = neff,
        estimate = estimate,
        variance = variance,
        missing_outcome = missing_outcome,
        estimable = if (is.null(outcome)) weight_sum > 0 else is.finite(estimate),
        stringsAsFactors = FALSE
      )
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  stat_cols <- c(
    "row_count", "weight_sum", "neff", "estimate",
    "variance", "missing_outcome", "estimable"
  )
  names(out)[names(out) %in% stat_cols] <- paste0(
    names(out)[names(out) %in% stat_cols],
    "_",
    label
  )
  out
}

#' Merge online and offline cell summaries.
#'
#' @param online_cells Online cell summary.
#' @param offline_cells Offline cell summary.
#' @param by_cell Cell columns.
#' @keywords internal
#' @noRd
.wf_blend_merge_cells <- function(online_cells, offline_cells, by_cell) {
  keys <- c("group", by_cell)
  merged <- merge(
    online_cells,
    offline_cells,
    by = keys,
    all = TRUE,
    sort = FALSE
  )
  numeric_zero <- c(
    "row_count_online", "weight_sum_online", "neff_online",
    "missing_outcome_online", "row_count_offline",
    "weight_sum_offline", "neff_offline", "missing_outcome_offline"
  )
  for (col in intersect(numeric_zero, names(merged))) {
    merged[[col]][is.na(merged[[col]])] <- 0
  }
  logical_false <- c("estimable_online", "estimable_offline")
  for (col in intersect(logical_false, names(merged))) {
    merged[[col]][is.na(merged[[col]])] <- FALSE
  }
  merged
}

#' Compute data-driven lambda from effective sample sizes.
#'
#' @param cells Merged source cells.
#' @keywords internal
#' @noRd
.wf_blend_lambda_neff <- function(cells) {
  denom <- cells$neff_online + cells$neff_offline
  ifelse(denom > 0, cells$neff_online / denom, NA_real_)
}

#' Apply lambda trimming and one-source overrides.
#'
#' @param cells Merged source cells.
#' @param lambda_raw Raw lambda values.
#' @param lambda_strategy Strategy name.
#' @param trim_lambda Trim bounds.
#' @keywords internal
#' @noRd
.wf_blend_finalize_lambda <- function(cells, lambda_raw, lambda_strategy, trim_lambda) {
  online_ok <- cells$estimable_online
  offline_ok <- cells$estimable_offline

  lambda <- lambda_raw
  reason <- rep(lambda_strategy, length(lambda))
  trimmed <- rep(FALSE, length(lambda))

  only_online <- online_ok & !offline_ok
  only_offline <- !online_ok & offline_ok
  no_source <- !online_ok & !offline_ok
  both <- online_ok & offline_ok

  lambda[only_online] <- 1
  reason[only_online] <- "online_only"
  lambda[only_offline] <- 0
  reason[only_offline] <- "offline_only"

  trim_hit <- both & is.finite(lambda) &
    (lambda < trim_lambda[[1]] | lambda > trim_lambda[[2]])
  lambda[trim_hit] <- pmin(
    pmax(lambda[trim_hit], trim_lambda[[1]]),
    trim_lambda[[2]]
  )
  reason[trim_hit] <- "trimmed"
  trimmed[trim_hit] <- TRUE

  if (any(no_source)) {
    wf_abort(
      "At least one fusion cell has no estimable source.",
      "wf_error_feasibility",
      list(rows = which(no_source))
    )
  }

  data.frame(
    lambda = lambda,
    lambda_reason = reason,
    lambda_trimmed = trimmed,
    stringsAsFactors = FALSE
  )
}

#' Build scalar fixed lambda values.
#'
#' @param lambda_fixed User-supplied fixed lambda.
#' @param n Number of rows.
#' @keywords internal
#' @noRd
.wf_blend_fixed_scalar <- function(lambda_fixed, n) {
  if (!is.numeric(lambda_fixed) || length(lambda_fixed) != 1 ||
    is.na(lambda_fixed) || !is.finite(lambda_fixed) ||
    lambda_fixed < 0 || lambda_fixed > 1) {
    wf_abort("Scalar `lambda_fixed` must be one finite value inside [0, 1].", "wf_error_input")
  }
  rep(as.numeric(lambda_fixed), n)
}

#' Blend online and offline calibrated estimates
#'
#' Combines two `wf_weights` sources at the estimator level. Each source is
#' estimated within each fusion cell first; the source estimates are then
#' combined using the effective lambda recorded in the result.
#'
#' @param online Online-source `wf_weights`.
#' @param offline Offline-source `wf_weights`.
#' @param by_cell Character vector of cell columns.
#' @param lambda Lambda strategy: `"neff"`, `"inverse_variance"`, or `"fixed"`.
#' @param lambda_fixed Fixed lambda scalar or key table when `lambda = "fixed"`.
#' @param outcome Optional numeric outcome column.
#' @param level Lambda level: `"cell"` or `"group"`.
#' @param trim_lambda Two bounds used to clamp data-driven lambdas.
#' @param sensitivity Whether to compute a global-lambda sensitivity sweep.
#'
#' @return A `wf_blend_result` object.
#' @export
wf_blend <- function(online, offline, by_cell,
                     lambda = c("neff", "inverse_variance", "fixed"),
                     lambda_fixed = NULL,
                     outcome = NULL,
                     level = c("cell", "group"),
                     trim_lambda = c(0.05, 0.95),
                     sensitivity = TRUE) {
  t0 <- Sys.time()
  lambda <- .wf_blend_match(lambda, c("neff", "inverse_variance", "fixed"), "lambda")
  level <- .wf_blend_match(level, c("cell", "group"), "level")
  by_cell <- .wf_blend_by_cell(by_cell)
  trim_lambda <- .wf_blend_trim(trim_lambda)
  if (!is.null(outcome) && (length(outcome) != 1 || is.na(outcome) || !nzchar(outcome))) {
    wf_abort("`outcome` must be `NULL` or a single non-empty column name.", "wf_error_input")
  }
  sensitivity <- isTRUE(sensitivity)

  .wf_blend_check_source(online, "online", by_cell, outcome)
  .wf_blend_check_source(offline, "offline", by_cell, outcome)
  .wf_blend_check_fixed_required(lambda, lambda_fixed)

  online_cells <- .wf_blend_source_cells(online, "online", by_cell, outcome)
  offline_cells <- .wf_blend_source_cells(offline, "offline", by_cell, outcome)
  cells <- .wf_blend_merge_cells(online_cells, offline_cells, by_cell)

  if (lambda == "fixed") {
    lambda_raw <- .wf_blend_fixed_scalar(lambda_fixed, nrow(cells))
  } else {
    lambda_raw <- .wf_blend_lambda_neff(cells)
  }
  lambda_info <- .wf_blend_finalize_lambda(cells, lambda_raw, lambda, trim_lambda)
  cells <- cbind(cells, lambda_info)

  if (!is.null(outcome)) {
    cells$estimate <- cells$lambda * cells$estimate_online +
      (1 - cells$lambda) * cells$estimate_offline
    cells$variance <- (cells$lambda^2) * cells$variance_online +
      ((1 - cells$lambda)^2) * cells$variance_offline
    cells$cell_weight <- cells$lambda * cells$weight_sum_online +
      (1 - cells$lambda) * cells$weight_sum_offline
  }

  structure(
    list(
      estimates = if (is.null(outcome)) data.frame() else cells,
      summary = data.frame(),
      lambda = cells[c("group", by_cell, "lambda", "lambda_reason", "lambda_trimmed")],
      diagnostics = list(
        source_support = cells,
        trimmed_lambda_count = sum(cells$lambda_trimmed),
        one_source_cell_count = sum(cells$lambda_reason %in% c("online_only", "offline_only"))
      ),
      sensitivity = if (sensitivity) data.frame() else NULL,
      provenance = list(
        method = "blend",
        by_cell = by_cell,
        outcome = outcome,
        lambda = lambda,
        level = level,
        trim_lambda = trim_lambda,
        sources = list(
          online = online$provenance,
          offline = offline$provenance
        ),
        assumptions = c(
          "Convex fusion assumes both source estimates are approximately unbiased for the cell quantity.",
          "Online-source unbiasedness depends on calibration variables explaining the selection mechanism.",
          "Sensitivity output exposes dependence on lambda choices."
        ),
        created = t0,
        elapsed = as.numeric(Sys.time() - t0, units = "secs"),
        package_version = .wf_blend_package_version()
      )
    ),
    class = "wf_blend_result"
  )
}
