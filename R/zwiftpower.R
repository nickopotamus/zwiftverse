# ZwiftPower ------------------------------------------------------------------
# No bearer auth - needs a logged-in phpBB session cookie (phpbb3_lswlk_sid),
# obtained via Zwift SSO. Two ways in:
#   (a) zp_set_cookie(s, "<sid>")  - paste the cookie from browser devtools. Robust.
#   (b) zp_login(s, user, pass)    - programmatic SSO (needs rvest+xml2; brittle).
# Endpoints: cache3/*.json (static) and api3.php?do=* (dynamic).

.ZP_BASE  <- "https://zwiftpower.com"
.ZP_LOGIN <- "https://zwiftpower.com/ucp.php?mode=login&login=external&oauth_service=oauthzpsso"

#' Create a ZwiftPower session
#'
#' @param cookie_file Path to an on-disk cookie jar (used by [zp_login()]).
#' @param sid Optional `phpbb3_lswlk_sid` value (see [zp_set_cookie()]).
#' @return An object of class `zp_session`.
#' @export
zp_session <- function(cookie_file = tempfile(fileext = ".cookies"), sid = NULL) {
  structure(list(cookie_file = cookie_file, sid = sid), class = "zp_session")
}

#' Set the ZwiftPower session cookie directly
#'
#' The robust alternative to [zp_login()]: log in at zwiftpower.com in a browser,
#' copy the `phpbb3_lswlk_sid` cookie value from devtools, and pass it here.
#'
#' @param s A [zp_session()].
#' @param sid The `phpbb3_lswlk_sid` cookie value.
#' @return The updated session.
#' @export
zp_set_cookie <- function(s, sid) { s$sid <- sid; s }

#' Log in to ZwiftPower via Zwift SSO (best effort)
#'
#' Scrapes the Keycloak login form and submits your Zwift credentials. This is
#' brittle - if the SSO flow changes it will fail; use [zp_set_cookie()] instead.
#' Requires the suggested packages \pkg{rvest} and \pkg{xml2}.
#'
#' @param s A [zp_session()].
#' @param username,password Zwift credentials (default to env vars).
#' @return Invisibly, the session.
#' @export
zp_login <- function(s, username = Sys.getenv("ZWIFT_USERNAME"),
                     password = Sys.getenv("ZWIFT_PASSWORD")) {
  .zv_need(c("rvest", "xml2"))
  cf <- s$cookie_file
  land <- request(.ZP_LOGIN) |>
    req_cookie_preserve(cf) |> req_user_agent(.ZWIFT_UA) |>
    req_error(body = function(resp) resp_body_string(resp)) |> req_perform()
  html <- xml2::read_html(resp_body_string(land))
  form <- rvest::html_element(html, "form")
  if (length(form) == 0 || inherits(form, "xml_missing"))
    stop("Could not find SSO login form; use zp_set_cookie() instead.", call. = FALSE)
  action <- rvest::html_attr(form, "action")
  inputs <- rvest::html_elements(form, "input")
  fields <- stats::setNames(as.list(rvest::html_attr(inputs, "value")),
                            rvest::html_attr(inputs, "name"))
  fields <- fields[!is.na(names(fields))]
  fields$username <- username; fields$password <- password
  fields <- lapply(fields, function(v) if (is.na(v)) "" else v)
  request(action) |>
    req_cookie_preserve(cf) |> req_user_agent(.ZWIFT_UA) |>
    req_body_form(!!!fields) |>
    req_error(body = function(resp) resp_body_string(resp)) |> req_perform()
  ok <- request(paste0(.ZP_BASE, "/events.php")) |>
    req_cookie_preserve(cf) |> req_user_agent(.ZWIFT_UA) |> req_perform() |>
    resp_body_string()
  if (!grepl("Profile", ok, fixed = TRUE))
    warning("Login may have failed (no 'Profile' marker). Try zp_set_cookie().")
  invisible(s)
}

#' Low-level ZwiftPower GET
#'
#' @param s A [zp_session()].
#' @param url A full URL or a path under `zwiftpower.com`.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds (`0` = off, `Inf` = permanent).
#' @param ... For the typed wrappers, further arguments forwarded to `zp_get()`.
#' @return A tibble, parsed list, or httr2 response.
#' @export
zp_get <- function(s, url, parse = "tbl", ttl = .zv_ttl("zp")) {
  stopifnot(inherits(s, "zp_session"))
  if (!grepl("^https?://", url)) url <- paste0(.ZP_BASE, url)
  req <- request(url) |>
    req_user_agent(.ZWIFT_UA) |>
    req_headers(Accept = "application/json") |>
    req_retry(max_tries = 3) |>
    req_error(body = function(resp) resp_body_string(resp))
  if (!is.null(s$sid)) req <- req_headers(req, Cookie = paste0("phpbb3_lswlk_sid=", s$sid))
  else                 req <- req_cookie_preserve(req, s$cookie_file)
  .zv_fetch(req, parse, ttl)
}

# -- static cache3 JSON --
#' @describeIn zp_get Rider profile (all data).
#' @param zwift_id Zwift rider id.
#' @export
zp_profile <- function(s, zwift_id, ...)
  zp_get(s, sprintf("/cache3/profile/%s_all.json", zwift_id), ...)

#' @describeIn zp_get Event results.
#' @param race_id ZwiftPower event id.
#' @export
zp_result <- function(s, race_id, ...)
  zp_get(s, sprintf("/cache3/results/%s_view.json", race_id), ...)

#' @describeIn zp_get Event signups.
#' @export
zp_signups <- function(s, race_id, ...)
  zp_get(s, sprintf("/cache3/results/%s_signups.json", race_id), ...)

#' @describeIn zp_get Team roster.
#' @param team_id ZwiftPower team id.
#' @export
zp_team <- function(s, team_id, ...)
  zp_get(s, sprintf("/cache3/teams/%s_riders.json", team_id), ...)

#' @describeIn zp_get Upcoming event list.
#' @export
zp_event_list <- function(s, ...)
  zp_get(s, "/cache3/lists/0_zwift_event_list_3.json", ...)

#' @describeIn zp_get Recent results list.
#' @export
zp_result_list <- function(s, ...)
  zp_get(s, "/cache3/lists/0_zwift_event_list_results_3.json", ...)

# -- dynamic api3.php --
#' @describeIn zp_get Team riders (api3).
#' @export
zp_team_riders <- function(s, team_id, ...)
  zp_get(s, sprintf("/api3.php?do=team_riders&id=%s", team_id), ...)

#' @describeIn zp_get List of teams (api3).
#' @export
zp_team_list <- function(s, ...)
  zp_get(s, "/api3.php?do=team_list", ...)

#' @describeIn zp_get Fastest-through-segment (FTS) data for an event.
#' @export
zp_sprints <- function(s, race_id, ...)
  zp_get(s, sprintf("/api3.php?do=event_sprints&zid=%s", race_id), ...)

#' @describeIn zp_get Prime (intermediate sprint/KOM) results for an event.
#' @param category,prime_type Optional ZwiftPower prime filters.
#' @export
zp_primes <- function(s, race_id, category = "", prime_type = "", ...)
  zp_get(s, sprintf("/api3.php?do=event_primes&zid=%s&category=%s&prime_type=%s",
                    race_id, category, prime_type), ...)

#' @describeIn zp_get List of leagues.
#' @export
zp_league_list <- function(s, ...)
  zp_get(s, "/api3.php?do=league_list", ...)

#' @describeIn zp_get League event results.
#' @param id League / league-event id.
#' @export
zp_league_results <- function(s, id, ...)
  zp_get(s, sprintf("/api3.php?do=league_event_results&id=%s", id), ...)

#' @describeIn zp_get League team event standings.
#' @export
zp_league_team_standings <- function(s, id, ...)
  zp_get(s, sprintf("/api3.php?do=league_team_event_standings&id=%s", id), ...)
