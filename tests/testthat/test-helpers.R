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

test_that("memory layer serves repeat hits without the disk, honours TTL, clears", {
  d <- file.path(tempdir(), paste0("zv-cache-", as.integer(runif(1, 1, 1e6))))
  old <- options(zwiftverse.cache = TRUE, zwiftverse.cache_dir = d,
                 zwiftverse.cache_memory = TRUE)
  on.exit(options(old), add = TRUE)

  key <- "mem-test-key"
  zwiftverse:::.zv_cache_set(key, list(v = 1))
  unlink(zwiftverse:::.zv_cache_path(key))           # disk copy gone...
  expect_equal(zwiftverse:::.zv_cache_get(key, ttl = Inf)$v, 1)  # ...memory still serves
  Sys.sleep(1)
  expect_null(zwiftverse:::.zv_cache_get(key, ttl = 0.001))       # TTL still applies

  zwiftverse:::.zv_cache_set(key, list(v = 2))
  zv_cache_clear()
  expect_null(zwiftverse:::.zv_cache_get(key, ttl = Inf))         # cleared from both

  options(zwiftverse.cache_memory = FALSE)
  zwiftverse:::.zv_cache_set(key, list(v = 3))
  unlink(zwiftverse:::.zv_cache_path(key))
  expect_null(zwiftverse:::.zv_cache_get(key, ttl = Inf))         # memory layer off
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

test_that(".zv_paged walks start/limit pages and stops on a short page", {
  data <- lapply(0:122, function(i) list(id = i))
  calls <- list()
  fetch <- function(pos, n) {
    calls[[length(calls) + 1]] <<- c(pos, n)
    data[seq_len(n) + pos][!vapply(data[seq_len(n) + pos], is.null, logical(1))]
  }
  all <- zwiftverse:::.zv_paged(fetch, page_max = 50)
  expect_equal(all$id, 0:122)
  expect_equal(calls, list(c(0, 50), c(50, 50), c(100, 50)))

  calls <- list()
  some <- zwiftverse:::.zv_paged(fetch, start = 10, limit = 60, page_max = 50)
  expect_equal(some$id, 10:69)
  expect_equal(calls, list(c(10, 50), c(60, 10)))
})

test_that(".zv_paged returns an empty tibble when there is nothing", {
  out <- zwiftverse:::.zv_paged(function(pos, n) list(), page_max = 50)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0)
})

test_that(".zv_bind reconciles column types that differ between pages", {
  a <- tibble::tibble(id = 1:2, note = c(NA, NA))          # logical
  b <- tibble::tibble(id = 3L, note = "x")                  # character
  c <- tibble::tibble(id = 4L, note = 5L)                   # integer
  out <- zwiftverse:::.zv_bind(list(a, b, c))
  expect_equal(nrow(out), 4)
  expect_equal(out$note, c(NA, NA, "x", "5"))
})

test_that(".zp_unescape decodes ZwiftPower HTML entities", {
  x <- tibble::tibble(name = c("Eibert van&#039;t Hof", "A &amp; B", "&quot;Q&quot; &#x1F98C;", NA),
                      n = 1:4)
  out <- zwiftverse:::.zp_unescape(x)
  expect_equal(out$name, c("Eibert van't Hof", "A & B", "\"Q\" \U0001F98C", NA))
  expect_equal(out$n, 1:4)
})

test_that(".zp_unescape decodes accented letters and leaves unknown names alone", {
  x <- tibble::tibble(name = c("Martin M&uuml;ller (Rhino)", "Ren&eacute; &Aring;str&ouml;m",
                               "Pe&ntilde;a &amp; Sk&aelig;r &szlig;", "&OElig;uvre &Scaron;imon",
                               "&amp;uuml; stays", "&notanentity; kept", "M&uuml;ller&#0;"))
  out <- zwiftverse:::.zp_unescape(x)
  expect_equal(out$name, c("Martin M\u00fcller (Rhino)", "Ren\u00e9 \u00c5str\u00f6m",
                           "Pe\u00f1a & Sk\u00e6r \u00df", "\u0152uvre \u0160imon",
                           "&uuml; stays", "&notanentity; kept", "M\u00fcller&#0;"))
})
