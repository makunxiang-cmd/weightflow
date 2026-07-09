make_blend_weights <- function(source = "online",
                               group = c("A", "A", "A", "A"),
                               cell = c("urban", "urban", "rural", "rural"),
                               weight = c(1, 1, 1, 1),
                               outcome = c(1, 0, 1, 0)) {
  data <- data.frame(
    id = paste0(source, "_", seq_along(group)),
    group = group,
    cell = cell,
    weight = weight,
    outcome = outcome,
    stringsAsFactors = FALSE
  )
  structure(
    list(
      data = data,
      log = data.frame(
        group = unique(group),
        iterations = NA_integer_,
        converged = TRUE,
        trimmed = 0L,
        stringsAsFactors = FALSE
      ),
      achieved = NULL,
      provenance = list(method = source, created = Sys.time())
    ),
    class = "wf_weights"
  )
}

test_that("wf_blend is exported", {
  expect_true(is.function(wf_blend))
})

test_that("wf_blend validates source objects and required columns", {
  online <- make_blend_weights("online")
  offline <- make_blend_weights("offline")

  expect_error(
    wf_blend(list(), offline, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_input"
  )
  expect_error(
    wf_blend(online, list(), by_cell = "cell", outcome = "outcome"),
    class = "wf_error_input"
  )

  missing_group <- online
  missing_group$data$group <- NULL
  expect_error(
    wf_blend(missing_group, offline, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_schema"
  )

  missing_cell <- offline
  missing_cell$data$cell <- NULL
  expect_error(
    wf_blend(online, missing_cell, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_schema"
  )

  missing_weight <- offline
  missing_weight$data$weight <- NULL
  expect_error(
    wf_blend(online, missing_weight, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_schema"
  )

  missing_outcome <- online
  missing_outcome$data$outcome <- NULL
  expect_error(
    wf_blend(missing_outcome, offline, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_schema"
  )
})

test_that("wf_blend validates weights, outcome, lambda, level, and trim settings", {
  online <- make_blend_weights("online")
  offline <- make_blend_weights("offline")

  bad_weight <- online
  bad_weight$data$weight[[1]] <- -1
  expect_error(
    wf_blend(bad_weight, offline, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_input"
  )

  bad_outcome <- online
  bad_outcome$data$outcome <- as.character(bad_outcome$data$outcome)
  expect_error(
    wf_blend(bad_outcome, offline, by_cell = "cell", outcome = "outcome"),
    class = "wf_error_input"
  )

  expect_error(
    wf_blend(online, offline, by_cell = "cell", outcome = "outcome", lambda = "median"),
    class = "wf_error_input"
  )
  expect_error(
    wf_blend(online, offline, by_cell = "cell", outcome = "outcome", level = "province"),
    class = "wf_error_input"
  )
  expect_error(
    wf_blend(
      online,
      offline,
      by_cell = "cell",
      outcome = "outcome",
      trim_lambda = c(0.9, 0.1)
    ),
    class = "wf_error_input"
  )
  expect_error(
    wf_blend(online, offline, by_cell = "cell", outcome = "outcome", lambda = "fixed"),
    class = "wf_error_input"
  )
})
