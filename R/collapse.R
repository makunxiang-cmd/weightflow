#' Apply a category collapse plan
#'
#' Applies a category-merge map consistently to sample data and a target object.
#'
#' @param sample Sample data frame.
#' @param target A `wf_target` object.
#' @param plan List with `dim` and named character vector `map`.
#'
#' @return A list with collapsed `sample` and `target`.
#' @export
wf_apply_collapse <- function(sample, target, plan) {
  d <- plan$dim
  map <- plan$map
  if (!d %in% target$dims) {
    wf_abort(sprintf("Collapse plan targets unknown dimension '%s'.", d), "wf_error_input")
  }
  v <- .chr(sample[[d]])
  hit <- !is.na(v) & v %in% names(map)
  v[hit] <- map[v[hit]]
  sample[[d]] <- v
  for (g in names(target$groups)) {
    m <- target$groups[[g]]$margins[[d]]
    key <- names(m)
    hit <- key %in% names(map)
    key[hit] <- map[key[hit]]
    target$groups[[g]]$margins[[d]] <- .wf_margin_vector(tapply(as.numeric(m), key, sum))
  }
  .wf_validate_target(target)
  target$meta$collapsed <- c(target$meta$collapsed, list(plan))
  list(sample = sample, target = target)
}
