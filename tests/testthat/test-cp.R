# Offline tests for critical power / W' helpers (synthetic fixtures, no network).

test_that(".zv_cp_fit recovers CP and W' from an exact model curve", {
  secs <- c(60, 120, 180, 300, 600, 900, 1200, 1800)
  fit <- zwiftverse:::.zv_cp_fit(secs, 280 + 20000 / secs)
  expect_equal(fit$cp, 280, tolerance = 1e-8)
  expect_equal(fit$w_prime, 20000, tolerance = 1e-6)
  expect_equal(fit$r2, 1)
})

test_that(".zv_cp_fit refuses too few points and unphysical fits", {
  expect_null(zwiftverse:::.zv_cp_fit(c(120, 1200), c(400, 300)))
  secs <- c(120, 300, 600, 1200)
  expect_null(zwiftverse:::.zv_cp_fit(secs, 200 - 5000 / secs))   # W' < 0
})

test_that(".zp_pen_letter maps 1-5 to A-E", {
  expect_equal(zwiftverse:::.zp_pen_letter(c(1, 3, 5, 0, NA)), c("A", "C", "E", NA, NA))
})

test_that("zp_power_curve parses the 90-day and 30-day curves", {
  use_fixture("zp", "power_curve")
  out <- zp_power_curve(fake_zp(), 1000001)
  expect_named(out, c("secs", "watts", "date", "event_id"))
  expect_equal(out$watts[out$secs == 1200], round(280 + 20000 / 1200))
  expect_s3_class(out$date, "POSIXct")
  expect_equal(unique(out$event_id), "5800002")
  expect_equal(nrow(zp_power_curve(fake_zp(), 1000001, window = "nope")), 0)
})

# Serve ZR and ZP fixtures by URL pattern; unmatched URLs 404. `blocked` URL
# patterns answer 429 with a zero allowance, as ZwiftRacing does for a tier
# without access to that route. Returns an environment logging the URLs hit.
mock_apis <- function(routes = c(`/api/v2/riders/\\d+/results` = "zr/rider_results",
                                 `/api/v2/events/` = "zr/event",
                                 `/api/public/results/` = "zr/public_results",
                                 `/cache3/profile/` = "zp/profile",
                                 `critical_power_profile` = "zp/power_curve",
                                 `_signups` = "zp/signups"),
                      status = 200, blocked = character(), env = parent.frame()) {
  bodies <- lapply(routes, function(f) {
    p <- test_path("fixtures", paste0(f, ".json"))
    skip_if_not(file.exists(p), sprintf("fixture %s not recorded", f))
    readBin(p, "raw", file.size(p))
  })
  seen <- new.env(); seen$urls <- character()
  httr2::local_mocked_responses(function(req) {
    seen$urls <- c(seen$urls, req$url)
    if (status != 200) {
      return(httr2::response(status_code = status, url = req$url,
                             headers = list(`Content-Type` = "application/json"),
                             body = charToRaw('{"message":"Unauthorized"}')))
    }
    if (any(vapply(blocked, grepl, logical(1), x = req$url))) {
      return(httr2::response(status_code = 429, url = req$url,
                             headers = list(`Content-Type` = "application/json",
                                            `ratelimit-policy` = "0;w=60", `retry-after` = "60"),
                             body = charToRaw('{"error":"Too many requests","limit":0}')))
    }
    hit <- which(vapply(names(routes), grepl, logical(1), x = req$url))[1]
    if (is.na(hit)) return(httr2::response(status_code = 404, url = req$url))
    httr2::response(status_code = 200, url = req$url,
                    headers = list(`Content-Type` = "application/json"), body = bodies[[hit]])
  }, env = env)
  seen
}

test_that("zv_rider_cp (service key) takes CP and W' from the newest ZwiftRacing result", {
  mock_apis()
  local_mocked_bindings(.zv_now = function() as.POSIXct(1795200000, origin = "1970-01-01"))
  out <- zv_rider_cp(fake_zr_service(), fake_zp(), 1000001)
  expect_equal(out$source, "zwiftracing")
  expect_equal(out$event_id, "5800908")
  expect_equal(out$cp, 293.117927694581)
  expect_equal(out$w_prime, 24772.9280236167)
  expect_equal(out$age_days, (1795200000 - 1795116600) / 86400)
})

test_that("zv_rider_cp falls back to the ZwiftPower fit when ZR is too old or absent", {
  mock_apis()
  local_mocked_bindings(.zv_now = function() as.POSIXct(1795116600 + 200 * 86400, origin = "1970-01-01"))
  old <- zv_rider_cp(fake_zr_service(), fake_zp(), 1000001)
  expect_equal(old$source, "zwiftpower_fit")
  expect_equal(old$cp, 280, tolerance = 0.01)
  expect_equal(old$w_prime, 20000, tolerance = 0.01)
  expect_true(is.na(old$event_id))

  no_zr <- zv_rider_cp(NULL, fake_zp(), 1000001)
  expect_equal(no_zr$source, "zwiftpower_fit")
})

test_that("zv_rider_cp returns an NA row when neither source has data", {
  mock_apis(routes = c(`_none_` = "zp/signups"))   # every request 404s
  out <- zv_rider_cp(fake_zr(), fake_zp(), 1000001)
  expect_equal(nrow(out), 1)
  expect_true(is.na(out$cp) && is.na(out$source))
})

test_that("zv_rider_cp raises authentication errors instead of falling back", {
  mock_apis(status = 401)
  expect_error(zv_rider_cp(fake_zr_service(), NULL, 1000001), class = "httr2_http_401")
})

test_that("zv_signups_cp returns one row per signed-up rider, filterable by pen", {
  mock_apis()
  all <- zv_signups_cp(NULL, fake_zp(), 5800000, progress = FALSE)
  su  <- jsonlite::read_json(test_path("fixtures", "zp", "signups.json"))$data
  expect_equal(nrow(all), length(unique(vapply(su, `[[`, 0, "zwid"))))
  expect_true(all(all$source == "zwiftpower_fit"))
  expect_equal(all$cp_wkg, all$cp / all$weight)
  expect_true(all(all$pen %in% c(LETTERS[1:5], NA)))

  pen <- all$pen[!is.na(all$pen)][1]
  one <- zv_signups_cp(NULL, fake_zp(), 5800000, pen = pen, progress = FALSE)
  expect_true(all(one$pen == pen))
})

test_that("zv_signups_cp stops on an authentication failure", {
  use_fixture("zp", "signups")
  local_mocked_bindings(zv_rider_cp = function(...) {
    rlang::abort("nope", class = c("httr2_http_401", "httr2_http_error"))
  })
  expect_error(zv_signups_cp(fake_zr(), fake_zp(), 5800000, progress = FALSE),
               "Authentication failed")
})

test_that("zv_rider_cp (user key) finds races in ZwiftPower history, reads ZR public results", {
  seen <- mock_apis()
  prof <- jsonlite::read_json(test_path("fixtures", "zp", "profile.json"))$data
  newest <- max(vapply(prof, function(x) as.numeric(x$event_date), 0))
  local_mocked_bindings(.zv_now = function() as.POSIXct(newest + 86400, origin = "1970-01-01"))
  out <- zv_rider_cp(fake_zr(), fake_zp(), 1000001)
  expect_equal(out$source, "zwiftracing")
  expect_equal(out$cp, 293.117927694581)
  expect_equal(out$age_days, 1)
  expect_true(any(grepl("/api/public/results/", seen$urls)))
  expect_false(any(grepl("/api/v2/", seen$urls)))
})

test_that("a key with no results allowance warns and uses the ZwiftPower fit", {
  seen <- mock_apis(blocked = "/api/public/results/")
  prof <- jsonlite::read_json(test_path("fixtures", "zp", "profile.json"))$data
  newest <- max(vapply(prof, function(x) as.numeric(x$event_date), 0))
  local_mocked_bindings(.zv_now = function() as.POSIXct(newest + 86400, origin = "1970-01-01"))
  rlang::local_options(rlib_warning_verbosity = "verbose")
  expect_warning(out <- zv_rider_cp(fake_zr(), fake_zp(), 1000001), "can't read event results")
  expect_equal(out$source, "zwiftpower_fit")
  expect_true(isTRUE(attr(out, "zr_blocked")))
  expect_equal(sum(grepl("/api/public/results/", seen$urls)), 1)    # gave up after one
})

test_that("zv_signups_cp stops asking ZwiftRacing once results are blocked", {
  seen <- mock_apis(blocked = "/api/public/results/")
  prof <- jsonlite::read_json(test_path("fixtures", "zp", "profile.json"))$data
  newest <- max(vapply(prof, function(x) as.numeric(x$event_date), 0))
  local_mocked_bindings(.zv_now = function() as.POSIXct(newest + 86400, origin = "1970-01-01"))
  rlang::local_options(rlib_warning_verbosity = "quiet")
  out <- zv_signups_cp(fake_zr(), fake_zp(), 5800000, progress = FALSE)
  expect_gt(nrow(out), 2)
  expect_true(all(out$source == "zwiftpower_fit"))
  expect_equal(sum(grepl("/api/public/results/", seen$urls)), 1)
})
