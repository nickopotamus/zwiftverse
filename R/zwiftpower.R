# ZwiftPower ------------------------------------------------------------------
# No bearer auth - needs a logged-in phpBB session cookie (phpbb3_lswlk_sid),
# obtained via Zwift SSO. Two ways in:
#   (a) zp_set_cookie(s, "<sid>")  - paste the cookie from browser devtools. Robust.
#   (b) zp_login(s, user, pass)    - programmatic SSO (needs rvest+xml2; brittle).
# Endpoints: cache3/*.json (static) and api3.php?do=* (dynamic).
# cache3/ is served from CloudFront and needs signed cookies (CloudFront-Policy,
# -Signature, -Key-Pair-Id) that zwiftpower.com sets when a logged-in session
# loads an HTML page. zp_get() "primes" the cookie jar for that automatically.

.ZP_BASE  <- "https://zwiftpower.com"
.ZP_LOGIN <- "https://zwiftpower.com/ucp.php?mode=login&login=external&oauth_service=oauthzpsso"

#' Create a ZwiftPower session
#'
#' @param cookie_file Path to an on-disk cookie jar (used by [zp_login()]).
#' @param sid Optional `phpbb3_lswlk_sid` value (see [zp_set_cookie()]).
#' @return An object of class `zp_session`.
#' @export
zp_session <- function(cookie_file = tempfile(fileext = ".cookies"), sid = NULL) {
  st <- new.env(parent = emptyenv()); st$primed_at <- 0
  structure(list(cookie_file = cookie_file, sid = sid, .state = st), class = "zp_session")
}

.ZP_PRIME_TTL <- 1800   # re-fetch CloudFront cookies every 30 min

.zp_base_req <- function(s, url) {
  req <- request(url) |>
    req_user_agent(.ZWIFT_UA) |>
    req_cookie_preserve(s$cookie_file)
  if (!is.null(s$sid)) req <- req_headers(req, Cookie = paste0("phpbb3_lswlk_sid=", s$sid))
  req
}

# Load a logged-in HTML page so CloudFront signed cookies land in the jar.
.zp_prime <- function(s, force = FALSE) {
  st <- s$.state
  if (!is.environment(st)) return(invisible(s))
  if (!force && as.numeric(Sys.time()) - st$primed_at < .ZP_PRIME_TTL) return(invisible(s))
  resp <- .zp_base_req(s, paste0(.ZP_BASE, "/events.php")) |>
    req_error(is_error = function(resp) FALSE) |>
    req_perform()
  ck <- unlist(resp_headers(resp)[tolower(names(resp_headers(resp))) == "set-cookie"])
  if (!any(grepl("^CloudFront-Signature=", ck)) && !.zp_jar_has_cf(s$cookie_file))
    warning("ZwiftPower did not issue CloudFront cookies; cache3/ endpoints will ",
            "likely return 403. Is the session cookie still valid?", call. = FALSE)
  st$primed_at <- as.numeric(Sys.time())
  invisible(s)
}

.zp_jar_has_cf <- function(cf) {
  file.exists(cf) && any(grepl("CloudFront-Signature", readLines(cf, warn = FALSE), fixed = TRUE))
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
zp_set_cookie <- function(s, sid) {
  s$sid <- sid
  if (is.environment(s$.state)) s$.state$primed_at <- 0
  s
}

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
  if (is.environment(s$.state)) s$.state$primed_at <- 0
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
  if (grepl("/cache3/", url, fixed = TRUE) && !.zv_cache_fresh(url, ttl)) .zp_prime(s)
  req <- .zp_base_req(s, url) |>
    req_headers(Accept = "application/json") |>
    req_retry(max_tries = 3) |>
    req_error(body = function(resp) resp_body_string(resp))
  out <- .zv_fetch(req, parse, ttl)
  if (parse == "tbl") .zp_unescape(out) else out
}

# ZwiftPower HTML-escapes text (names arrive as "van&#039;t Hof"). Decode the
# common named entities and all numeric ones in character columns.
.zp_unescape <- function(tbl) {
  dec <- function(x) {
    if (!any(grepl("&", x, fixed = TRUE), na.rm = TRUE)) return(x)
    x <- gsub("&quot;", "\"", x, fixed = TRUE)
    x <- gsub("&lt;", "<", x, fixed = TRUE)
    x <- gsub("&gt;", ">", x, fixed = TRUE)
    x <- gsub("&apos;", "'", x, fixed = TRUE)
    m <- gregexpr("&#(x[0-9A-Fa-f]+|[0-9]+);", x, perl = TRUE)
    regmatches(x, m) <- lapply(regmatches(x, m), function(e) {
      if (!length(e)) return(e)
      code <- sub("^&#(.*);$", "\\1", e)
      n <- ifelse(startsWith(code, "x"), strtoi(substring(code, 2), 16L), strtoi(code, 10L))
      vapply(n, intToUtf8, character(1))
    })
    gsub("&amp;", "&", x, fixed = TRUE)
  }
  for (n in names(tbl)) if (is.character(tbl[[n]])) {
    ok <- !is.na(tbl[[n]])
    tbl[[n]][ok] <- dec(tbl[[n]][ok])
  }
  tbl
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
#' @param team_id ZwiftPower team id (optional for `zp_segment_standings()`).
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

#' @describeIn zp_get Best efforts on a ZwiftPower segment (one row per
#'   rider: `elapsed` seconds, average `power`, `weight`, `wkg`, and the `zid`
#'   / `date` of the event it was set in). Without `team_id` returns the global
#'   leaderboard (top ~2000); with it, every effort by that team's riders.
#'   Segment ids are the numbers in `zp_sprints()` column names (`msec.13`)
#'   and `zp_primes()`'s `sprint_id`; e.g. 13 = Watopia Epic KOM Forward.
#' @param segment_id ZwiftPower segment id.
#' @export
zp_segment_standings <- function(s, segment_id, team_id = NULL, ...)
  zp_get(s, paste0("/api3.php?do=segment_standings&id=", segment_id,
                   if (!is.null(team_id)) paste0("&team_id=", team_id)), ...)

#' Race-report data streams from ZwiftPower
#'
#' The data behind ZwiftPower's race report (`racereport.php`): a rider's
#' second-by-second power, heart rate and altitude through one event, from
#' `api3.php?do=analysis`.
#'
#' `zp_analysis()` fetches one rider. `zp_event_analysis()` fetches every
#' finisher in an event's results, optionally only one pen or a set of riders,
#' one request per rider (each cached, so re-runs are cheap).
#'
#' @param s A [zp_session()].
#' @param race_id ZwiftPower (= Zwift) event id.
#' @param zwift_id Zwift rider id.
#' @param parse `"tbl"` for the tidy stream tibble, or `"json"` / `"resp"` for
#'   the raw payload (`zp_analysis()` only).
#' @param ttl Cache time-to-live in seconds.
#' @return A tibble with one row per sample: `zwid`, `time` (seconds from the
#'   rider's start), `distance` (km), then one column per stream ZwiftPower
#'   holds for the rider — usually `power` (W), `heart_rate` (bpm) and
#'   `altitude` (m); `cadence` (rpm) and `speed` (km/h) appear when present,
#'   other streams are named after their unit. A rider with no data gives zero
#'   rows. `zp_event_analysis()` adds `name` and `category` from the results.
#' @export
#' @examples
#' \dontrun{
#' zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
#' winner <- zp_analysis(zp, 5811034, 1366959)
#' pen_b  <- zp_event_analysis(zp, 5811034, pen = "B")
#' }
zp_analysis <- function(s, race_id, zwift_id, parse = "tbl", ttl = .zv_ttl("zp")) {
  url <- sprintf("/api3.php?do=analysis&zwift_id=%s&zwift_event_id=%s", zwift_id, race_id)
  if (parse != "tbl") return(zp_get(s, url, parse = parse, ttl = ttl))
  .zp_analysis_tbl(zp_get(s, url, parse = "json", ttl = ttl), zwift_id)
}

.ZP_STREAM_NAMES <- c(watts = "power", bpm = "heart_rate", m = "altitude",
                      rpm = "cadence", kph = "speed", `km/h` = "speed")

.zp_analysis_tbl <- function(j, zwift_id) {
  empty <- tibble::tibble(zwid = integer(), time = numeric(), distance = numeric())
  if (!length(j) || !length(j$x2Data)) return(empty)
  n <- length(j$x2Data)
  out <- tibble::tibble(zwid = rep(as.integer(zwift_id), n),
                        time = as.numeric(j$x2Data),
                        distance = if (length(j$xData) == n) as.numeric(j$xData) else NA_real_)
  for (ds in j$datasets) {
    if (length(ds$data) != n) next
    unit <- ds$unit %||% "value"
    nm <- if (unit %in% names(.ZP_STREAM_NAMES)) .ZP_STREAM_NAMES[[unit]] else
      make.names(unit)
    if (nm %in% names(out)) nm <- make.unique(c(names(out), nm))[ncol(out) + 1]
    out[[nm]] <- as.numeric(ds$data)
  }
  out
}

#' @rdname zp_analysis
#' @param pen Optional pen (category) letter(s), e.g. `"B"`.
#' @param zwift_ids Optional rider ids to restrict to.
#' @param ... Passed to `zp_analysis()` (e.g. `ttl`).
#' @param progress Show a progress bar.
#' @export
zp_event_analysis <- function(s, race_id, pen = NULL, zwift_ids = NULL, ...,
                              progress = interactive()) {
  riders <- zp_result(s, race_id)
  if (!nrow(riders)) return(.zp_analysis_tbl(list(), NA))
  riders <- tibble::tibble(zwid = as.integer(riders$zwid), name = riders$name,
                           category = riders$category)
  if (!is.null(pen)) riders <- riders[riders$category %in% toupper(pen), ]
  if (!is.null(zwift_ids)) riders <- riders[riders$zwid %in% as.integer(zwift_ids), ]
  riders <- riders[!duplicated(riders$zwid), ]
  if (!nrow(riders)) rlang::abort("No riders in this event match `pen` / `zwift_ids`.")

  if (progress) {
    pb <- utils::txtProgressBar(max = nrow(riders), style = 3)
    on.exit(close(pb), add = TRUE)
  }
  pieces <- lapply(seq_len(nrow(riders)), function(i) {
    if (progress) utils::setTxtProgressBar(pb, i)
    tryCatch(zp_analysis(s, race_id, riders$zwid[i], ...), error = function(e) {
      rlang::warn(sprintf("Rider %s: %s", riders$zwid[i], conditionMessage(e)))
      NULL
    })
  })
  streams <- .zv_bind(pieces)
  if (!NROW(streams)) return(.zp_analysis_tbl(list(), NA))
  out <- dplyr::left_join(streams, riders, by = "zwid")
  dplyr::relocate(out, "name", "category", .after = "zwid")
}

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

#' Unwrap ZwiftPower `[value, flag]` columns
#'
#' Many ZwiftPower numeric fields arrive as small arrays rather than scalars,
#' which become list-columns in the returned tibble:
#'
#' * `[value, flag]` pairs — results/profile fields such as `avg_wkg`,
#'   `avg_power`, `time`, `weight`, `wkg1200`;
#' * `[code, value, percentile]` triples — the sign-up power bests
#'   (`cp_300_wkg`, `cp_1200_watts`, ...). Verified: element 2 is the value
#'   (`cp_*_watts[2] / weight == cp_*_wkg[2]`).
#'
#' `zp_unflag()` replaces every such column with its value, converted to
#' number where possible.
#'
#' @param tbl A tibble returned by a `zp_*()` function.
#' @return `tbl` with those list-columns replaced by atomic columns.
#' @export
#' @examples
#' x <- tibble::tibble(zwid = 1:2,
#'                     avg_wkg = list(c("3.8", "0"), c("4.1", "0")),
#'                     cp_300_wkg = list(c("8", "3.7", "23.4"), c("8", "4.2", "51.0")))
#' zp_unflag(x)
zp_unflag <- function(tbl) {
  unwrap_len <- function(col) {
    if (!is.list(col) || !length(col)) return(NA_integer_)
    ok <- vapply(col, function(v) is.null(v) || (is.atomic(v) && length(v) %in% c(0, 2, 3)), logical(1))
    if (!all(ok)) return(NA_integer_)
    lens <- unique(lengths(col)[lengths(col) > 0])
    if (length(lens) == 1) lens else if (!length(lens)) 2L else NA_integer_
  }
  for (n in names(tbl)) {
    len <- unwrap_len(tbl[[n]])
    if (is.na(len)) next
    pick <- if (len == 3) 2L else 1L
    vals <- vapply(tbl[[n]], function(v) if (length(v)) as.character(v[[pick]]) else NA_character_,
                   character(1))
    vals[vals == ""] <- NA_character_
    tbl[[n]] <- utils::type.convert(vals, as.is = TRUE)
  }
  tbl
}
