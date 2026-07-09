#' Run cell-level post-stratification
#'
#' Applies calibration-style post-stratification to a sample using a joint-cell
#' population target built with `wf_target_population(..., keep_joint = TRUE)`.
#'
#' @param sample Sample data frame.
#' @param target A `wf_target` object with joint cells.
#' @param min_cell Minimum sample count per resolved cell.
#' @param ladder A `wf_collapse_ladder` object.
#' @param init_weight Optional initial weight column. If `NULL`, all initial
#'   weights are one.
#' @param granularity Resolution strategy, either `"adaptive"` or `"province"`.
#' @param empty_cell Empty-cell policy, one of `"redistribute"`, `"flag"`, or
#'   `"error"`.
#' @param id Optional unique unit identifier column.
#' @param precheck Reserved for the workflow contract; validation always runs.
#' @param tol Relative tolerance for enforced group-total checks.
#'
#' @return A `wf_weights` object with `cell_report` and `collapse_map`.
#' @export
wf_poststrat <- function(sample, target, min_cell, ladder,
                         init_weight = NULL,
                         granularity = c("adaptive", "province"),
                         empty_cell = c("redistribute", "flag", "error"),
                         id = NULL, precheck = TRUE, tol = 1e-8) {
  granularity <- match.arg(granularity)
  empty_cell <- match.arg(empty_cell)
  t0 <- Sys.time()
  .wf_check_poststrat_args(sample, target, min_cell, ladder)

  dvars <- target$dims
  gkey <- .wf_group_keys(sample, target$by)
  ids <- if (is.null(id)) seq_len(nrow(sample)) else sample[[id]]
  iw <- if (is.null(init_weight)) rep(1, nrow(sample)) else sample[[init_weight]]
  if (any(!is.finite(iw)) || any(iw <= 0)) {
    wf_abort("Initial weights must be finite and > 0.", "wf_error_input")
  }

  res_rows <- list()
  logs <- list()
  reports <- list()
  maps <- list()

  for (g in intersect(names(target$joint), unique(gkey))) {
    sel <- which(gkey == g)
    smat <- as.matrix(sapply(dvars, function(d) .chr(sample[[d]][sel])))
    if (is.null(dim(smat))) {
      smat <- matrix(smat, ncol = length(dvars), dimnames = list(NULL, dvars))
    }
    jdf <- target$joint[[g]]
    raw_jkey <- .wf_cell_key(as.matrix(jdf[, dvars, drop = FALSE]), dvars)
    res <- .wf_resolve_group(smat, jdf, dvars, ladder, min_cell, granularity, g)

    if (res$granularity_used == "province" && granularity == "adaptive") {
      wf_warn(
        sprintf(
          "Group '%s': adaptive resolution insufficient; degraded to province-uniform.",
          g
        ),
        "wf_warning_quality",
        list(group = g)
      )
    }

    pop_flagged <- 0
    if (any(res$orphan)) {
      if (empty_cell == "error") {
        wf_abort(
          sprintf(
            "Group '%s': %d population cell(s) have zero sample support and empty_cell='error'.",
            g,
            sum(res$orphan)
          ),
          "wf_error_feasibility",
          list(group = g, n_orphan = sum(res$orphan))
        )
      }
      if (empty_cell == "redistribute") {
        res <- .wf_redistribute(res, min_cell, g)
        if (!is.null(res$redist_log)) {
          wf_warn(
            sprintf(
              "Group '%s': redistributed %d orphan cell(s) into supported ancestors.",
              g,
              nrow(res$redist_log)
            ),
            "wf_warning_data",
            list(group = g)
          )
        }
      } else {
        pop_flagged <- sum(jdf$pop[res$orphan])
        wf_warn(
          sprintf(
            "Group '%s': %d orphan cell(s) flagged; %s population left unassigned.",
            g,
            sum(res$orphan),
            format(round(pop_flagged), big.mark = ",")
          ),
          "wf_warning_data",
          list(group = g)
        )
      }
    }

    pop_by_res <- tapply(jdf$pop[!res$orphan], res$resolved[!res$orphan], sum)
    lvl_of_raw <- stats::setNames(res$level_used, res$raw_key)
    s_raw <- .wf_cell_key(smat, dvars)
    s_res <- rep(NA_character_, length(sel))

    in_pop <- s_raw %in% res$raw_key
    if (any(in_pop)) {
      wr <- which(in_pop)
      lv_i <- as.integer(lvl_of_raw[s_raw[in_pop]])
      s_res[in_pop] <- vapply(seq_along(wr), function(j) {
        .wf_cell_key(
          .wf_apply_ladder(smat[wr[j], , drop = FALSE], ladder, lv_i[j]),
          dvars
        )
      }, character(1))
    }

    if (any(!in_pop)) {
      valid_res <- unique(res$resolved)
      for (idxrow in which(!in_pop)) {
        assigned <- NA_character_
        for (lv in 0:(length(res$s_keys) - 1)) {
          k <- .wf_cell_key(
            .wf_apply_ladder(smat[idxrow, , drop = FALSE], ladder, lv),
            dvars
          )
          if (k %in% valid_res) {
            assigned <- k
            break
          }
        }
        s_res[idxrow] <- assigned
      }
      n_drop <- sum(is.na(s_res))
      if (n_drop > 0) {
        wf_warn(
          sprintf(
            "Group '%s': %d respondent(s) fall in cells with no populated resolved match; excluded.",
            g,
            n_drop
          ),
          "wf_warning_data",
          list(group = g)
        )
      }
    }

    known <- !is.na(s_res)
    iw_g <- iw[sel]
    denom <- tapply(iw_g[known], s_res[known], sum)
    common <- intersect(names(pop_by_res), names(denom))
    factor <- stats::setNames(pop_by_res[common] / denom[common], common)

    w <- rep(NA_real_, length(sel))
    w[known] <- iw_g[known] * factor[s_res[known]]
    w[is.na(w)] <- 0

    full_total <- target$groups[[g]]$total
    expected_total <- full_total - pop_flagged
    realized <- sum(w)
    constraint_dev <- if (expected_total > 0) {
      abs(realized - expected_total) / expected_total
    } else {
      0
    }
    if (constraint_dev > tol) {
      wf_abort(
        sprintf(
          "Group '%s': group-total constraint violated (realized %.6g vs target %.6g, dev %.2e). This indicates an internal bug.",
          g,
          realized,
          expected_total,
          constraint_dev
        ),
        "wf_error_internal",
        list(group = g, dev = constraint_dev)
      )
    }
    total_dev <- if (full_total > 0) abs(realized - full_total) / full_total else 0

    wt_known <- w[known]
    cv <- if (length(wt_known) > 1 && mean(wt_known) > 0) {
      stats::sd(wt_known) / mean(wt_known)
    } else {
      NA_real_
    }

    res_rows[[g]] <- data.frame(
      id = ids[sel],
      group = g,
      resolved_cell = s_res,
      weight = w,
      feature = 1 / w,
      stringsAsFactors = FALSE
    )

    cellw_mean <- tapply(w[known], s_res[known], mean)
    rep_g <- data.frame(
      group = g,
      jdf[, dvars, drop = FALSE],
      pop = jdf$pop,
      n_sample = res$supp_final,
      ladder_level_used = res$level_used,
      resolved_cell = res$resolved,
      granularity_used = res$granularity_used,
      orphan = res$orphan,
      redistributed_to = NA_character_,
      pop_moved = 0,
      final_cell_weight_mean = unname(cellw_mean[res$resolved]),
      stringsAsFactors = FALSE
    )
    if (!is.null(res$redist_log)) {
      moved_idx <- match(res$redist_log$raw_cell, raw_jkey)
      hit <- !is.na(moved_idx)
      rep_g$redistributed_to[moved_idx[hit]] <- res$redist_log$receiving_cell[hit]
      rep_g$pop_moved[moved_idx[hit]] <- rep_g$pop[moved_idx[hit]]
    }
    reports[[g]] <- rep_g

    maps[[g]] <- data.frame(
      group = g,
      raw_cell = res$raw_key,
      resolved_cell = res$resolved,
      level = res$level_used,
      stringsAsFactors = FALSE
    )

    logs[[g]] <- data.frame(
      group = g,
      n = length(sel),
      n_cells_raw = nrow(jdf),
      n_cells_resolved = length(unique(res$resolved)),
      granularity_used = res$granularity_used,
      n_orphan_cells = if (is.null(res$redist_log)) sum(res$orphan) else nrow(res$redist_log),
      pop_redistributed = sum(rep_g$pop_moved),
      total_target = full_total,
      total_realized = realized,
      total_dev = total_dev,
      iterations = NA_integer_,
      converged = TRUE,
      trimmed = 0L,
      deff = round(1 + cv^2, 3),
      stringsAsFactors = FALSE
    )
  }

  structure(
    list(
      data = do.call(rbind, res_rows),
      log = do.call(rbind, logs),
      achieved = NULL,
      cell_report = do.call(rbind, reports),
      collapse_map = structure(
        list(
          map = do.call(rbind, maps),
          settings = list(min_cell = min_cell, granularity = granularity)
        ),
        class = "wf_poststrat_plan"
      ),
      provenance = list(
        method = "poststrat",
        dims = dvars,
        by = target$by,
        min_cell = min_cell,
        granularity = granularity,
        empty_cell = empty_cell,
        init_weight = init_weight,
        ladder_levels = ladder$n_levels,
        created = t0,
        elapsed = as.numeric(Sys.time() - t0, units = "secs"),
        package_version = "0.2.0"
      )
    ),
    class = "wf_weights"
  )
}
