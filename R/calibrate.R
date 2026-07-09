#' Calibrate weights with a selected method
#'
#' Dispatches to the requested calibration engine while preserving the common
#' `wf_weights` return contract.
#'
#' @param sample Sample data frame.
#' @param target A `wf_target` object.
#' @param method Calibration method: `"raking"`, `"poststrat"`, `"greg"`
#'   (linear GREG), or `"logit"` (bounded, requires `bounds = c(L, U)`).
#' @param ... Method-specific arguments. For `"greg"` / `"logit"`: `bounds`,
#'   `init_weight`, `na`, `id`, `tol`, `max_iter`, `precheck`.
#'
#' @return A `wf_weights` object.
#' @export
wf_calibrate <- function(sample, target, method = "raking", ...) {
  supported <- c("raking", "poststrat", "greg", "logit")
  if (length(method) != 1 || !method %in% supported) {
    shown <- if (length(method) == 0) "<empty>" else as.character(method[[1]])
    wf_abort(
      sprintf(
        "Unsupported calibration method '%s'. Supported methods: raking, poststrat, greg, logit.",
        shown
      ),
      "wf_error_input",
      list(method = method)
    )
  }

  if (method == "raking") {
    out <- wf_rake(sample, target, ...)
    out$provenance$method <- "raking"
    return(out)
  }

  if (method == "poststrat") {
    return(wf_poststrat(sample, target, ...))
  }

  bounds <- list(...)$bounds
  if (method == "logit") {
    if (is.null(bounds) || length(bounds) != 2 || !is.numeric(bounds) ||
        anyNA(bounds) || !(bounds[1] > 0 && bounds[1] < 1 && bounds[2] > 1)) {
      wf_abort(
        "method='logit' requires bounds = c(L, U) with 0 < L < 1 < U.",
        "wf_error_input", list(bounds = bounds)
      )
    }
  }

  distance <- if (method == "greg") "linear" else "logit"
  .wf_lincalibrate(sample, target, distance = distance, method = method, ...)
}
