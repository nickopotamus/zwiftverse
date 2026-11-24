# Offline tests for zwift_auth() token lifecycle (no network): a mock token
# endpoint records which grants were requested and can be told to reject them.

mock_auth_server <- function(env = parent.frame(), refresh_status = 200,
                             expires_in = 3600, refresh_expires_in = 1800,
                             api_401_once = FALSE) {
  log <- new.env()
  log$grants <- character(); log$n <- 0; log$api_tokens <- character()
  withr::local_options(zwiftverse.zwift_auth_url = "https://auth.test/token",
                       zwiftverse.cache = FALSE, .local_envir = env)
  httr2::local_mocked_responses(function(req) {
    if (grepl("auth.test", req$url, fixed = TRUE)) {
      grant <- req$body$data$grant_type
      log$grants <- c(log$grants, grant)
      if (grant == "refresh_token" && refresh_status != 200)
        return(httr2::response(status_code = refresh_status, url = req$url,
                               body = charToRaw('{"error":"invalid_grant"}')))
      log$n <- log$n + 1
      body <- jsonlite::toJSON(list(access_token = paste0("tok", log$n),
                                    refresh_token = paste0("ref", log$n),
                                    expires_in = expires_in,
                                    refresh_expires_in = refresh_expires_in),
                               auto_unbox = TRUE)
      return(httr2::response(status_code = 200, url = req$url,
                             headers = list(`Content-Type` = "application/json"),
                             body = charToRaw(body)))
    }
    tok <- sub("^Bearer ", "", httr2::req_get_headers(req, "reveal")$Authorization)
    log$api_tokens <- c(log$api_tokens, tok)
    if (api_401_once && length(log$api_tokens) == 1)
      return(httr2::response(status_code = 401, url = req$url))
    httr2::response(status_code = 200, url = req$url,
                    headers = list(`Content-Type` = "application/json"),
                    body = charToRaw('{"id": 1}'))
  }, env = env)
  log
}

test_that("first token() logs in; later calls reuse the cached token", {
  log <- mock_auth_server()
  a <- zwift_auth("u", "p")
  expect_equal(a$token(), "tok1")
  expect_equal(a$token(), "tok1")
  expect_equal(log$grants, "password")
})

test_that("expired access token is renewed with the refresh token", {
  log <- mock_auth_server()
  a <- zwift_auth("u", "p")
  a$token()
  a$.state$access_exp <- 0
  expect_equal(a$token(), "tok2")
  expect_equal(log$grants, c("password", "refresh_token"))
})

test_that("a rejected refresh falls back to a password login", {
  log <- mock_auth_server(refresh_status = 400)
  a <- zwift_auth("u", "p")
  a$token()
  a$.state$access_exp <- 0
  expect_equal(a$token(), "tok2")
  expect_equal(log$grants, c("password", "refresh_token", "password"))
})

test_that("expiry is set early and measured from the request", {
  log <- mock_auth_server(expires_in = 300)
  before <- as.numeric(Sys.time())
  a <- zwift_auth("u", "p"); a$token()
  # 300 s lifetime -> renewed 30 s early, counted from before the request
  expect_lte(a$.state$access_exp, before + 300 - 30 + 1)
  expect_gte(a$.state$access_exp, before + 300 - 30 - 5)
})

test_that("refresh_expires_in = 0 (offline token) never expires", {
  log <- mock_auth_server(refresh_expires_in = 0)
  a <- zwift_auth("u", "p"); a$token()
  expect_equal(a$.state$refresh_exp, Inf)
})

test_that("a 401 on an API call discards the token and retries once", {
  log <- mock_auth_server(api_401_once = TRUE)
  a <- zwift_auth("u", "p")
  out <- zwift_get(a, "/api/profiles/me", parse = "json", ttl = 0)
  expect_equal(out$id, 1)
  expect_equal(log$api_tokens, c("tok1", "tok2"))
})

test_that("print() never shows the token or credentials", {
  log <- mock_auth_server()
  a <- zwift_auth("secret-user", "secret-pass"); a$token()
  out <- paste(capture.output(print(a)), collapse = "\n")
  expect_match(out, "access token")
  expect_false(grepl("tok1|ref1|secret", out))
})
