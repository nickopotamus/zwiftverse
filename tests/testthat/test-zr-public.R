# ZwiftRacing.app with a user (Hobby) key: Authorization header, public routes,
# batch POST, and the errors for zero-allowance and service-only routes.

# Record each request, answer from a fixture or with a canned status.
mock_zr <- function(fixture = NULL, status = 200, headers = list(), env = parent.frame()) {
  seen <- new.env(); seen$reqs <- list()
  body <- if (!is.null(fixture)) {
    p <- test_path("fixtures", "zr", paste0(fixture, ".json"))
    readBin(p, "raw", file.size(p))
  } else charToRaw('{"error":"Too many requests, please try again later.","retryAfter":"60","windowMinutes":1,"limit":0}')
  httr2::local_mocked_responses(function(req) {
    seen$reqs[[length(seen$reqs) + 1]] <- req
    httr2::response(status_code = status, url = req$url, method = req$method %||% "GET",
                    headers = c(list(`Content-Type` = "application/json"), headers), body = body)
  }, env = env)
  seen
}

test_that("zr_client defaults to a user key and prints without the key", {
  zr <- zr_client("secret-key-123")
  expect_equal(zr$key_type, "user")
  expect_output(print(zr), "user key")
  expect_false(any(grepl("secret-key-123", capture.output(print(zr)))))
  expect_equal(zr_client("k", key_type = "service")$key_type, "service")
})

test_that("a user key is sent as Authorization to /api/public/riders", {
  seen <- mock_zr("public_rider")
  out <- zr_rider(fake_zr(), 1000001)
  req <- seen$reqs[[1]]
  expect_equal(req$url, "https://api.zwiftracing.app/api/public/riders/1000001")
  expect_true("Authorization" %in% names(req$headers))
  expect_false("x-api-key" %in% names(req$headers))
  expect_equal(nrow(out), 1)
  expect_true(all(c("riderId", "power", "velo", "race") %in% names(out)))
})

test_that("zr_rider(time =) asks for a snapshot", {
  seen <- mock_zr("public_rider")
  zr_rider(fake_zr(), 1000001, time = as.POSIXct(1795000000, origin = "1970-01-01"))
  expect_match(seen$reqs[[1]]$url, "/api/public/riders/1000001/1795000000$")
})

test_that("a service key keeps x-api-key on the v2 routes", {
  seen <- mock_zr("rider")
  zr_rider(fake_zr_service(), 1000001)
  req <- seen$reqs[[1]]
  expect_equal(req$url, "https://api.zwiftracing.app/api/v2/riders/1000001")
  expect_true("x-api-key" %in% names(req$headers))
})

test_that("zr_riders sends one POST per 1000 ids with a JSON array body", {
  seen <- mock_zr("public_riders")
  out <- zr_riders(fake_zr(), c(1000001, 1000003, 1000001))
  expect_length(seen$reqs, 1)
  req <- seen$reqs[[1]]
  expect_equal(req$method, "POST")
  expect_match(req$url, "/api/public/riders$")
  expect_equal(unlist(req$body$data), c(1000001L, 1000003L))     # de-duplicated
  expect_equal(nrow(out), 2)

  seen2 <- mock_zr("public_riders")
  zr_riders(fake_zr(), seq_len(2500), ttl = 0)
  expect_length(seen2$reqs, 3)
  expect_equal(lengths(lapply(seen2$reqs, function(r) r$body$data)), c(1000, 1000, 500))
})

test_that("a zero allowance fails at once with zv_zr_no_access, without retrying", {
  seen <- mock_zr(status = 429, headers = list(`ratelimit-policy` = "0;w=60", `retry-after` = "60"))
  zr <- zr_client("key-for-no-access-test")
  err <- expect_error(zr_result(zr, 5800908), class = "zv_zr_no_access")
  expect_match(conditionMessage(err), "no allowance")
  expect_length(seen$reqs, 1)
  # The route is remembered: the next event fails without a request.
  expect_error(zr_result(zr, 5800909), class = "zv_zr_no_access")
  expect_length(seen$reqs, 1)
  # Other routes, and other keys, are unaffected.
  expect_error(zr_result(zr_client("another-key"), 5800909), class = "zv_zr_no_access")
  expect_length(seen$reqs, 2)
})

test_that("a long rate-limit wait is reported, not slept through", {
  seen <- mock_zr(status = 429, headers = list(`ratelimit-policy` = "2;w=600", `retry-after` = "540"))
  expect_error(zr_riders(fake_zr(), 1:3), "try again in 540 s")
  expect_length(seen$reqs, 1)
})

test_that("service-only functions refuse a user key with a clear error", {
  for (f in list(function() zr_rider_results(fake_zr(), 1),
                 function() zr_rider_power(fake_zr(), 1),
                 function() zr_rider_velo(fake_zr(), 1),
                 function() zr_rider_overview(fake_zr(), 1),
                 function() zr_rider_ranking(fake_zr(), 1),
                 function() zr_event(fake_zr(), 1),
                 function() zr_routes(fake_zr()))) {
    expect_error(f(), class = "zv_zr_service_only")
  }
})

test_that("user-key zr_result reads /api/public/results and returns records", {
  seen <- mock_zr("public_results")
  out <- zr_result(fake_zr(), 5800908)
  expect_match(seen$reqs[[1]]$url, "/api/public/results/5800908$")
  expect_gt(nrow(out), 1)
  expect_true("riderId" %in% names(out))
})

test_that("zr_route_weights needs exactly one of laps or distance", {
  expect_error(zr_route_weights(fake_zr(), 1), "exactly one")
  expect_error(zr_route_weights(fake_zr(), 1, laps = 1, distance = 1000), "exactly one")
  seen <- mock_zr("public_rider")
  zr_route_weights(fake_zr(), 1365497350, laps = 2, parse = "json")
  expect_match(seen$reqs[[1]]$url, "/api/v2/public/routes/1365497350/factor-weights\\?laps=2&eventType=race$")
})
