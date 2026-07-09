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

  structure(
    list(
      estimates = data.frame(),
      summary = data.frame(),
      lambda = data.frame(),
      diagnostics = list(),
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
