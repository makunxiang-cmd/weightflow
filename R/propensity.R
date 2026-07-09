#' Return the loaded package version for provenance.
#'
#' @keywords internal
#' @noRd
.wf_propensity_package_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("weightflow")),
    error = function(e) "0.6.0"
  )
}

#' Build a propensity target: stacked reference frame and membership model spec.
#'
#' Stacks a self-selected `online` sample and a probability `reference` sample
#' into one frame with a membership indicator, so the online sample's selection
#' propensity can be modelled. No model is fit here; execution happens in
#' [wf_propensity()].
#'
#' @param online Data frame: the self-selected (non-probability) sample.
#' @param reference Data frame: the probability reference sample.
#' @param formula Two-sided membership formula, e.g. `member ~ age + edu`. The
#'   right-hand side names the model predictors; the left-hand side names the
#'   membership indicator the constructor creates (`1` online, `0` reference).
#' @param method Fit backend. Only `"logit"` is executable in this release;
#'   `"rf"` / `"gbm"` are reserved and abort in [wf_propensity()].
#' @param by Optional grouping column present in both frames; the propensity
#'   model is fit within each group.
#' @param id Optional id column in `online`; when `NULL`, online units are
#'   identified by row order.
#' @return A `wf_target_propensity` object.
#' @export
wf_target_propensity <- function(online, reference, formula,
                                 method = c("logit", "rf", "gbm"),
                                 by = NULL, id = NULL) {
  method <- match.arg(method)
  if (!is.data.frame(online) || nrow(online) == 0) {
    wf_abort("`online` must be a non-empty data frame.", "wf_error_input")
  }
  if (!is.data.frame(reference) || nrow(reference) == 0) {
    wf_abort("`reference` must be a non-empty data frame.", "wf_error_input")
  }
  if (!inherits(formula, "formula") || length(formula) != 3) {
    wf_abort(
      "`formula` must be a two-sided formula, e.g. member ~ age + edu.",
      "wf_error_input"
    )
  }
  membership <- all.vars(formula[[2]])
  if (length(membership) != 1) {
    wf_abort(
      "The left-hand side of `formula` must be a single membership name.",
      "wf_error_input"
    )
  }
  predictors <- all.vars(formula[[3]])
  if (length(predictors) == 0) {
    wf_abort(
      "`formula` must name at least one predictor on the right-hand side.",
      "wf_error_input"
    )
  }
  if (membership %in% predictors) {
    wf_abort(
      sprintf("Membership name '%s' collides with a predictor.", membership),
      "wf_error_input", list(membership = membership)
    )
  }
  miss_online <- setdiff(predictors, names(online))
  if (length(miss_online) > 0) {
    wf_abort(
      sprintf("`online` is missing predictor(s): %s",
              paste(miss_online, collapse = ", ")),
      "wf_error_input", list(missing = miss_online)
    )
  }
  miss_ref <- setdiff(predictors, names(reference))
  if (length(miss_ref) > 0) {
    wf_abort(
      sprintf("`reference` is missing predictor(s): %s",
              paste(miss_ref, collapse = ", ")),
      "wf_error_input", list(missing = miss_ref)
    )
  }
  if (!is.null(by)) {
    if (length(by) != 1 || !is.character(by)) {
      wf_abort("`by` must be a single column name.", "wf_error_input")
    }
    if (!by %in% names(online)) {
      wf_abort(sprintf("`online` is missing `by` column '%s'.", by),
               "wf_error_input", list(by = by))
    }
    if (!by %in% names(reference)) {
      wf_abort(sprintf("`reference` is missing `by` column '%s'.", by),
               "wf_error_input", list(by = by))
    }
  }
  if (!is.null(id)) {
    if (length(id) != 1 || !is.character(id)) {
      wf_abort("`id` must be a single column name.", "wf_error_input")
    }
    if (!id %in% names(online)) {
      wf_abort(sprintf("`online` is missing `id` column '%s'.", id),
               "wf_error_input", list(id = id))
    }
  }

  keep <- unique(c(predictors, by))
  online_part <- online[, keep, drop = FALSE]
  online_part[[membership]] <- 1L
  online_part$.wf_source <- "online"
  ref_part <- reference[, keep, drop = FALSE]
  ref_part[[membership]] <- 0L
  ref_part$.wf_source <- "reference"
  stacked <- rbind(online_part, ref_part)

  online_ids <- if (is.null(id)) {
    as.character(seq_len(nrow(online)))
  } else {
    .chr(online[[id]])
  }

  structure(list(
    online = online,
    reference = reference,
    stacked = stacked,
    membership = membership,
    predictors = predictors,
    formula = formula,
    method = method,
    by = by,
    id = id,
    online_ids = online_ids,
    n_online = nrow(online),
    n_reference = nrow(reference),
    provenance = list(
      created = Sys.time(),
      package_version = .wf_propensity_package_version()
    )
  ), class = "wf_target_propensity")
}
