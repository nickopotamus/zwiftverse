# Offline fixture harness. Fixtures are recorded (and PII-scrubbed) by
# dev/capture-fixtures.R into tests/testthat/fixtures/<api>/<endpoint>.json.
# Each test serves the recorded bytes through httr2's mocking hook, so the full
# request -> .zv_fetch() -> .zv_to_tbl() path runs without network or creds.
# Tests skip until the corresponding fixture exists.

options(zwiftverse.cache = FALSE)

fixture_path <- function(api, name) test_path("fixtures", api, paste0(name, ".json"))

use_fixture <- function(api, name, env = parent.frame()) {
  p <- fixture_path(api, name)
  skip_if_not(file.exists(p), sprintf("fixture %s/%s not recorded (run dev/capture-fixtures.R)", api, name))
  body <- readBin(p, "raw", file.size(p))
  httr2::local_mocked_responses(function(req) {
    httr2::response(status_code = 200, url = req$url, method = req$method %||% "GET",
                    headers = list(`Content-Type` = "application/json"), body = body)
  }, env = env)
  invisible(p)
}

fixture_ids <- function() {
  p <- test_path("fixtures", "ids.json")
  ids <- if (file.exists(p)) jsonlite::read_json(p) else list()
  if (is.null(ids$rider_id)) ids$rider_id <- 1000001
  ids
}

`%||%` <- function(a, b) if (is.null(a)) b else a

fake_zwift <- function() {
  st <- new.env(); st$me_id <- 1000001          # skip the "me" -> id lookup
  structure(list(token = function() "test-token", .state = st), class = "zwift_auth")
}
fake_zr    <- function() zwiftverse::zr_client(auth = "test-key")
fake_zp    <- function() {
  s <- zwiftverse::zp_set_cookie(zwiftverse::zp_session(), "test-sid")
  s$.state$primed_at <- as.numeric(Sys.time())  # skip CloudFront cookie priming
  s
}
