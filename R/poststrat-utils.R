#' Build joint cell keys.
#'
#' @param mat Character matrix containing dimension columns.
#' @param dvars Dimension column names.
#' @keywords internal
#' @noRd
.wf_cell_key <- function(mat, dvars) {
  do.call(paste, c(lapply(dvars, function(d) mat[, d]), sep = "\r"))
}

#' Split joint cell keys back into dimension columns.
#'
#' @param keys Cell keys built by `.wf_cell_key()`.
#' @param dvars Dimension column names.
#' @keywords internal
#' @noRd
.wf_split_key <- function(keys, dvars) {
  parts <- do.call(rbind, strsplit(keys, "\r", fixed = TRUE))
  df <- as.data.frame(parts, stringsAsFactors = FALSE)
  names(df) <- dvars
  df
}

#' Apply cumulative collapse ladder maps.
#'
#' @param mat Character matrix containing dimension columns.
#' @param ladder A `wf_collapse_ladder` object.
#' @param lv Highest ladder level to apply.
#' @keywords internal
#' @noRd
.wf_apply_ladder <- function(mat, ladder, lv) {
  if (lv == 0) {
    return(mat)
  }
  for (k in seq_len(lv)) {
    step <- ladder$steps[[k]]
    for (d in names(step)) {
      map <- step[[d]]
      col <- mat[, d]
      hit <- !is.na(col) & col %in% names(map)
      col[hit] <- map[col[hit]]
      mat[, d] <- col
    }
  }
  mat
}
