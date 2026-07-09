#' Return the loaded package version for provenance.
#'
#' @keywords internal
#' @noRd
.wf_replicates_package_version <- function() {
  tryCatch(
    as.character(utils::packageVersion("weightflow")),
    error = function(e) "0.7.0"
  )
}

#' Resolve the sampling design (strata and PSUs) from data columns.
#'
#' @param data Input data frame.
#' @param strata Stratum column name or `NULL` (single stratum).
#' @param clusters PSU column name or `NULL` (each row is its own PSU).
#' @keywords internal
#' @noRd
.wf_design <- function(data, strata, clusters) {
  n <- nrow(data)
  if (!is.null(strata)) {
    if (length(strata) != 1 || !is.character(strata) ||
        !strata %in% names(data)) {
      wf_abort("`strata` must name a column in `data`.",
               "wf_error_input", list(strata = strata))
    }
    stratum <- .chr(data[[strata]])
  } else {
    stratum <- rep("1", n)
  }
  if (!is.null(clusters)) {
    if (length(clusters) != 1 || !is.character(clusters) ||
        !clusters %in% names(data)) {
      wf_abort("`clusters` must name a column in `data`.",
               "wf_error_input", list(clusters = clusters))
    }
    cluster <- .chr(data[[clusters]])
  } else {
    cluster <- as.character(seq_len(n))
  }

  pairs <- unique(data.frame(stratum = stratum, cluster = cluster,
                             stringsAsFactors = FALSE))
  dup <- pairs$cluster[duplicated(pairs$cluster)]
  if (length(dup) > 0) {
    wf_abort(
      sprintf("Clusters are not nested within strata: %s appear in >1 stratum.",
              paste(unique(dup), collapse = ", ")),
      "wf_error_design", list(clusters = unique(dup))
    )
  }

  strata_levels <- unique(stratum)
  psu <- lapply(strata_levels, function(h) unique(cluster[stratum == h]))
  names(psu) <- strata_levels
  list(n = n, stratum = stratum, cluster = cluster,
       strata = strata_levels, psu = psu)
}

#' Rao-Wu rescaled bootstrap multipliers.
#'
#' @param design A `.wf_design()` result.
#' @param R Number of replicates.
#' @param seed Optional integer seed.
#' @keywords internal
#' @noRd
.wf_boot_mult <- function(design, R, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n <- design$n
  mult <- matrix(1, n, R)
  for (h in design$strata) {
    psus <- design$psu[[h]]
    nh <- length(psus)
    if (nh < 2) next
    units_by_psu <- lapply(psus, function(p) {
      which(design$stratum == h & design$cluster == p)
    })
    for (r in seq_len(R)) {
      draw <- sample.int(nh, nh - 1, replace = TRUE)
      counts <- tabulate(draw, nbins = nh)
      a <- (nh / (nh - 1)) * counts
      for (i in seq_len(nh)) {
        mult[units_by_psu[[i]], r] <- a[i]
      }
    }
  }
  list(mult = mult, scale = 1 / R, rscales = rep(1, R))
}

#' Stratified delete-one-PSU jackknife multipliers.
#'
#' @param design A `.wf_design()` result.
#' @keywords internal
#' @noRd
.wf_jack_mult <- function(design) {
  n <- design$n
  cols <- list()
  rscales <- numeric(0)
  for (h in design$strata) {
    psus <- design$psu[[h]]
    nh <- length(psus)
    in_h <- design$stratum == h
    if (nh < 2) {
      wf_warn(
        sprintf("Stratum '%s' has a single PSU; it cannot be jackknifed and contributes no replicate.", h),
        "wf_warning_quality", list(stratum = h)
      )
      next
    }
    for (p in psus) {
      m <- rep(1, n)
      m[in_h] <- nh / (nh - 1)
      m[in_h & design$cluster == p] <- 0
      cols[[length(cols) + 1]] <- m
      rscales <- c(rscales, (nh - 1) / nh)
    }
  }
  if (length(cols) == 0) {
    wf_abort("No stratum has >= 2 PSUs; jackknife has no replicates.",
             "wf_error_design")
  }
  list(mult = do.call(cbind, cols), scale = 1, rscales = rscales)
}

#' Sylvester-construction Hadamard matrix of order >= `n` (a power of two).
#'
#' @param n Minimum order.
#' @keywords internal
#' @noRd
.wf_hadamard <- function(n) {
  k <- 1
  while (k < n) k <- k * 2
  H <- matrix(1, 1, 1)
  while (nrow(H) < k) {
    H <- rbind(cbind(H, H), cbind(H, -H))
  }
  H
}

#' Balanced Repeated Replication multipliers (standard half-sampling).
#'
#' @param design A `.wf_design()` result; every stratum must have 2 PSUs.
#' @keywords internal
#' @noRd
.wf_brr_mult <- function(design) {
  sizes <- vapply(design$psu, length, integer(1))
  bad <- design$strata[sizes != 2]
  if (length(bad) > 0) {
    wf_abort(
      sprintf("BRR requires exactly 2 PSUs per stratum; not met by: %s.",
              paste(bad, collapse = ", ")),
      "wf_error_design", list(strata = bad)
    )
  }
  H <- length(design$strata)
  hmat <- .wf_hadamard(H + 1)
  R <- nrow(hmat)
  n <- design$n
  mult <- matrix(1, n, R)
  for (hi in seq_along(design$strata)) {
    h <- design$strata[hi]
    psus <- design$psu[[h]]
    in_h <- design$stratum == h
    u1 <- in_h & design$cluster == psus[1]
    u2 <- in_h & design$cluster == psus[2]
    for (r in seq_len(R)) {
      if (hmat[r, hi + 1] > 0) {
        mult[u1, r] <- 2
        mult[u2, r] <- 0
      } else {
        mult[u1, r] <- 0
        mult[u2, r] <- 2
      }
    }
  }
  list(mult = mult, scale = 1 / R, rscales = rep(1, R))
}
