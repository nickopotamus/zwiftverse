# Offline tests for the JSON -> tibble converter and the cache (no network).

test_that(".zv_to_tbl handles an array of records (data.frame)", {
  df <- data.frame(id = c(1, 2), name = c("a", "b"), stringsAsFactors = FALSE)
  out <- zwiftverse:::.zv_to_tbl(df)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 2)
  expect_equal(out$name, c("a", "b"))
})

test_that(".zv_to_tbl unwraps a {data:[...]} envelope", {
  parsed <- list(data = data.frame(id = c(10, 11), w = c(3.1, 4.2)))
  out <- zwiftverse:::.zv_to_tbl(parsed)
  expect_equal(nrow(out), 2)
  expect_equal(out$id, c(10, 11))
})

test_that(".zv_to_tbl turns a single object into a one-row tibble with list-cols", {
  parsed <- list(id = 42, name = "solo", race = list(rating = 1200, cat = "B"))
  out <- zwiftverse:::.zv_to_tbl(parsed)
  expect_equal(nrow(out), 1)
  expect_equal(out$id, 42)
  expect_true(is.list(out$race))        # nested object kept as list-column
})

test_that(".zv_to_tbl binds a bare list of records", {
  parsed <- list(list(id = 1, v = "x"), list(id = 2, v = "y"))
  out <- zwiftverse:::.zv_to_tbl(parsed)
  expect_equal(nrow(out), 2)
  expect_equal(out$v, c("x", "y"))
})

test_that("cache set / get / clear round-trips and respects TTL", {
  d <- file.path(tempdir(), paste0("zv-cache-", as.integer(runif(1, 1, 1e6))))
  old <- options(zwiftverse.cache = TRUE, zwiftverse.cache_dir = d)
  on.exit(options(old), add = TRUE)

  key <- "unit-test-key"
  zwiftverse:::.zv_cache_set(key, list(ok = TRUE))
  expect_equal(zwiftverse:::.zv_cache_get(key, ttl = Inf)$ok, TRUE)

  # expired entry returns NULL
  Sys.sleep(1)
  expect_null(zwiftverse:::.zv_cache_get(key, ttl = 0.001))

  info <- zv_cache_info()
  expect_true(key %in% info$key)
  expect_gte(zv_cache_clear(), 1)
})

test_that("cache key is stable for the same request and differs across urls", {
  r1 <- httr2::request("https://x/api/a")
  r2 <- httr2::request("https://x/api/a")
  r3 <- httr2::request("https://x/api/b")
  expect_equal(zwiftverse:::.zv_key(r1), zwiftverse:::.zv_key(r2))
  expect_false(identical(zwiftverse:::.zv_key(r1), zwiftverse:::.zv_key(r3)))
})

test_that(".zv_to_tbl unwraps a ZR v2 {success, data: {object}} envelope", {
  parsed <- list(success = TRUE, data = list(riderId = 7, velo = list(race = 700)))
  out <- zwiftverse:::.zv_to_tbl(parsed)
  expect_equal(nrow(out), 1)
  expect_equal(out$riderId, 7)
  expect_true(is.list(out$velo))
})
