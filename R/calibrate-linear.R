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
