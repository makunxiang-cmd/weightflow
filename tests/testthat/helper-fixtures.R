make_weightflow_fixture <- function() {
  sample <- data.frame(
    id = sprintf("r%02d", 1:16),
    province = rep(c("A", "B"), each = 8),
    gender = rep(c("female", "male", "female", "male"), times = 4),
    age = rep(c("young", "young", "old", "old"), times = 4),
    stringsAsFactors = FALSE
  )

  pop <- data.frame(
    province = rep(c("A", "B"), each = 4),
    gender = rep(c("female", "male", "female", "male"), times = 2),
    age = rep(c("young", "young", "old", "old"), times = 2),
    count = c(40, 60, 60, 40, 30, 70, 50, 50),
    stringsAsFactors = FALSE
  )

  dims <- wf_dims(
    gender = c("female", "male"),
    age = c("young", "old")
  )

  target <- wf_target_population(
    pop = pop,
    key_map = c(gender = "gender", age = "age"),
    count = "count",
    dims = dims,
    by = "province"
  )

  list(sample = sample, pop = pop, dims = dims, target = target)
}
