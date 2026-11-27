# ZwiftRacing.app --------------------------------------------------------------
# Host: https://api.zwiftracing.app
#
# Docs: https://zwiftracing.app/developer (checked 2026-11-27).
#
# Two kinds of key, two route families:
#
# * "user" keys (the default): the per-account key from ZwiftRacing.app
#   Settings (Hobby API Access membership). Sent as `Authorization: <key>`
#   (raw, no "Bearer") to the public routes. Hobby keys reach:
#     GET  /api/public/riders/:id[/:time]      5 / min   single rider (or snapshot)
#     POST /api/public/riders[/:time]          2 / 10 min  JSON array of <= 1000 ids
#     GET  /api/public/clubs/:id[/:riderId]    1 / 10 min  club + up to 1000 riders,
#                                              from riderId (inclusive), by id
#   plus a daily cap of 250 rider GETs and 15 POSTs (resets 00:00 UTC). These
#   are for event organisers only, set up with Tim directly:
#     GET  /api/public/results/:id             event results
#     GET  /api/public/zp/:id/results          ZwiftPower view of event results
#     GET  /api/v2/public/categories           vELO category bands
#     GET  /api/v2/public/routes/:id/factor-weights
#   A route outside the key's access answers 429 with `limit: 0` - "no access",
#   not "slow down" - so it is raised as `zv_zr_no_access` and never retried.
#   The daily cap is raised as `zv_zr_daily_limit`.
#
# * "service" keys (deprecated): the shared key behind the website's own v2
#   routes, sent as `x-api-key` to /api/v2/riders/..., /api/v2/events/...
#   Keys issued before accounts existed stop working on 1 January 2027, and
#   with them the functions that only exist on those routes (they raise
#   `zv_zr_service_only` with a user key).
#
# Read-only rule: it covers Zwift and ZwiftPower. ZwiftRacing's batch lookup is
# a read done by POST, which is fine.

.ZR_HOST <- "https://api.zwiftracing.app"
.ZR_BATCH_MAX <- 1000

#' Create a ZwiftRacing.app client
#'
#' @param auth Your ZwiftRacing.app API key. Defaults to the environment
#'   variable `ZR_AUTH`.
#' @param key_type `"user"` (default) for the per-account key from
#'   ZwiftRacing.app Settings -> API access, sent as `Authorization` to the
#'   public routes; or `"service"` for a shared service key, sent as
#'   `x-api-key` to the website's v2 routes (what this package used before
#'   November 2026). **Deprecated:** keys issued before ZwiftRacing.app
#'   accounts existed stop working on 1 January 2027; a `"service"` client
#'   warns once per session.
#' @param rate Throttle for `"service"` keys, in requests per second (default
#'   2). User keys are throttled per route to the limits the server reports.
#' @return An object of class `zr_client`.
#' @examples
#' \dontrun{
#' zr <- zr_client()                         # user key from ZR_AUTH
#' zr <- zr_client(Sys.getenv("ZR_SERVICE_KEY"), key_type = "service")
#' }
#' @export
zr_client <- function(auth = Sys.getenv("ZR_AUTH"), key_type = c("user", "service"),
                      rate = 2) {
  key_type <- match.arg(key_type)
  if (!nzchar(auth)) stop("Provide your ZwiftRacing.app key or set ZR_AUTH.", call. = FALSE)
  if (key_type == "service") {
    rlang::warn(c("ZwiftRacing.app service keys stop working on 1 January 2027.",
                  i = "Generate an account key in zwiftracing.app Settings (Hobby API Access) and use `zr_client(key)`.",
                  i = paste("`zr_rider_results()`, `zr_rider_power()`, `zr_rider_velo()`, `zr_rider_overview()`,",
                            "`zr_rider_ranking()`, `zr_event()` and `zr_routes()` need a service key and will be removed.")),
                class = "zv_zr_service_deprecated",
                .frequency = "once", .frequency_id = "zv_zr_service_key")
  }
  structure(list(auth = trimws(auth), key_type = key_type, rate = rate), class = "zr_client")
}

#' @export
print.zr_client <- function(x, ...) {
  cat(sprintf("<zr_client> %s key (%s), %d characters\n", x$key_type %||% "user",
              if (identical(x$key_type, "service")) "x-api-key on /api/v2" else
                "Authorization on /api/public", nchar(x$auth)))
  invisible(x)
}

.zr_is_service <- function(client) identical(client$key_type, "service")

# Per-route throttles for user keys: the documented Hobby limits (riders GET
# 5/min) or, for organiser-only routes, the limits seen in their headers.
# Routes with 10-minute windows (riders POST, clubs) are not throttled here:
# waiting silently for minutes is worse than a clear error.
.zr_user_throttle <- function(path, method) {
  if (grepl("^/api/public/riders", path) && method == "GET") return(c(5, 60))
  if (grepl("^/api/public/(results|zp)/", path)) return(c(1, 60))
  if (grepl("^/api/v2/public/", path)) return(c(5, 60))
  NULL
}

.zr_req <- function(client, path, method = "GET") {
  req <- request(paste0(.ZR_HOST, path)) |>
    req_user_agent(.zv_ua()) |>
    req_headers(Accept = "application/json")
  req <- if (.zr_is_service(client)) {
    req |>
      req_headers(`x-api-key` = client$auth, .redact = "x-api-key") |>
      # Token bucket: `rate` req/s averaged over a 60 s window.
      req_throttle(capacity = max(1L, as.integer(ceiling((client$rate %||% 2) * 60))),
                   fill_time_s = 60)
  } else {
    tl <- .zr_user_throttle(path, method)
    req <- req_headers(req, Authorization = client$auth, .redact = "Authorization")
    if (is.null(tl)) req else
      req_throttle(req, capacity = tl[[1]], fill_time_s = tl[[2]],
                   realm = paste0("zwiftracing:", .zr_route(path, method)))
  }
  req |>
    req_retry(max_tries = 4, is_transient = .zr_transient) |>
    req_error(body = .zr_err_body)
}

# The window a 429 asks us to wait, and the allowance it reports.
# The server's headers are preferred; the JSON body (`retryAfter`,
# `windowMinutes`, `limit`) fills any gap. `daily` is the 250 GET / 15 POST
# per-UTC-day cap (windowMinutes 1440).
.zr_limit <- function(resp) {
  b <- tryCatch(resp_body_json(resp), error = function(e) list())
  if (!is.list(b)) b <- list()
  num <- function(x) suppressWarnings(as.numeric(x %||% NA)[1])
  pol <- resp_header(resp, "ratelimit-policy")
  lim <- num(sub(";.*$", "", pol %||% NA))
  if (is.na(lim)) lim <- num(b$limit)
  wait <- num(resp_header(resp, "retry-after"))
  if (is.na(wait)) wait <- num(b$retryAfter)
  daily <- isTRUE(num(b$windowMinutes) >= 1440) || grepl("daily", b$error %||% "", ignore.case = TRUE)
  list(limit = lim, wait = wait, policy = pol, daily = daily)
}

# Retry 5xx, and 429s only when the route has an allowance and the wait is
# short. A 0 allowance or a long window is reported instead (see .zr_err_body).
.zr_transient <- function(resp) {
  s <- resp_status(resp)
  if (s %in% c(500, 502, 503)) return(TRUE)
  if (s != 429) return(FALSE)
  l <- .zr_limit(resp)
  !l$daily && !isTRUE(l$limit == 0) && (is.na(l$wait) || l$wait <= 120)
}

.zr_err_body <- function(resp) {
  s <- resp_status(resp)
  if (s == 429) {
    l <- .zr_limit(resp)
    if (isTRUE(l$limit == 0)) return(paste(.zr_no_access_msg(l$policy, resp_url(resp)), collapse = " "))
    if (l$daily) return(paste(.zr_daily_msg(l$limit), collapse = " "))
    return(sprintf("Rate limit reached (ratelimit-policy %s); try again in %s s.",
                   l$policy %||% "?", if (is.na(l$wait)) "?" else l$wait))
  }
  .zv_err_body(resp)
}

# Route family for throttling and the no-access memo: the path up to the first
# id, plus the method ("/api/public/results:GET").
.zr_route <- function(path, method) paste0(sub("/[0-9]+.*$", "", path), ":", method)

# Routes this session has seen a zero allowance for, per key. Remembered for 10
# minutes, so a loop over many riders fails fast instead of waiting on the
# throttle for a request that will be refused.
.zr_state <- new.env(parent = emptyenv())
.zr_memo_key <- function(client, route) paste(rlang::hash(client$auth), route)
.zr_forget <- function() rm(list = ls(.zr_state), envir = .zr_state)

# Routes ZwiftRacing.app keeps for event organisers (not in Hobby access).
.zr_organiser_only <- function(path)
  grepl("/api/public/(results|zp|ladder)|/api/v2/public/(categories|routes)", path %||% "")

.zr_no_access_msg <- function(policy, path = NULL) {
  if (.zr_organiser_only(path)) {
    return(c("This ZwiftRacing.app endpoint is for event organisers only; Hobby API Access keys can't use it.",
             i = "Organiser access is set up with Tim directly: https://zwiftracing.app/contact"))
  }
  c(sprintf("Your ZwiftRacing.app key has no allowance for this endpoint (ratelimit-policy %s).",
            policy %||% "0"),
    i = "See https://zwiftracing.app/developer for what each key can reach.")
}

.zr_daily_msg <- function(limit = NA) {
  c(sprintf("ZwiftRacing.app daily request limit reached%s.",
            if (is.na(limit)) "" else sprintf(" (%s for this route)", limit)),
    i = "Hobby keys get 250 rider GETs and 15 POSTs per UTC day; the count resets at 00:00 UTC.")
}

# Run a request; turn a zero-allowance 429 into a classed condition so callers
# (zv_rider_cp) can tell "this key can't use this route" from other failures.
.zr_fetch <- function(req, parse, ttl, client, route) {
  mk <- .zr_memo_key(client, route)
  seen <- .zr_state[[mk]]
  if (!is.null(seen) && as.numeric(Sys.time()) - seen$at < 600) {
    cached <- parse != "resp" && zv_cache_enabled() && !identical(ttl, 0) &&
      !is.null(.zv_cache_get(.zv_key(req), ttl))
    if (!cached) rlang::abort(.zr_no_access_msg(seen$policy, req$url), class = "zv_zr_no_access")
  }
  tryCatch(.zv_fetch(req, parse, ttl), httr2_http_429 = function(e) {
    l <- if (!is.null(e$resp)) .zr_limit(e$resp) else list(limit = NA, daily = FALSE)
    if (isTRUE(l$limit == 0)) {
      .zr_state[[mk]] <- list(at = as.numeric(Sys.time()), policy = l$policy)
      rlang::abort(.zr_no_access_msg(l$policy, req$url), class = "zv_zr_no_access", parent = e)
    }
    if (isTRUE(l$daily)) rlang::abort(.zr_daily_msg(l$limit), class = "zv_zr_daily_limit", parent = e)
    rlang::cnd_signal(e)
  })
}

.zr_need_service <- function(client, fn) {
  if (.zr_is_service(client)) return(invisible(TRUE))
  rlang::abort(c(sprintf("`%s()` uses a ZwiftRacing.app route that only accepts the shared service key.", fn),
                 i = "Account (Hobby) keys can reach riders and clubs: see `?zr_get`.",
                 i = "Service keys stop working on 1 January 2027, and this function will be removed.",
                 i = "If you have a service key, use `zr_client(key, key_type = \"service\")`."),
               class = "zv_zr_service_only")
}

#' Low-level ZwiftRacing.app request
#'
#' `zr_get()` sends a GET to any ZwiftRacing.app route. `path` is relative to
#' the host (`https://api.zwiftracing.app`), e.g. `"/api/public/riders/123"` or,
#' with a service key, `"/api/v2/riders/123"`. For a `"service"` client, a path
#' without a leading `/api/` is taken as relative to `/api/v2`, as in earlier
#' versions.
#'
#' **What each key reaches** (see <https://zwiftracing.app/developer>). A
#' Hobby API Access key (the default user key) can call `zr_rider()` (5 a
#' minute), `zr_riders()` (2 batch requests every 10 minutes), `zr_club()` and
#' `zr_club_riders()` (1 request every 10 minutes), with a daily cap of 250
#' rider GETs and 15 POSTs per UTC day. `zr_result()`, `zr_zp_result()`,
#' `zr_categories()` and `zr_route_weights()` are for event organisers only,
#' with access set up by ZwiftRacing.app directly. The rest
#' (`zr_rider_overview()`, `zr_rider_results()`, `zr_rider_ranking()`,
#' `zr_rider_velo()`, `zr_rider_power()`, `zr_event()`, `zr_routes()`) exist
#' only on the website's v2 routes and need a shared service key; those keys
#' stop working on 1 January 2027, and these functions will then be removed.
#'
#' **Errors.** A route your key has no access to fails at once with class
#' `zv_zr_no_access`; the daily cap fails with class `zv_zr_daily_limit`; a
#' service-only function called with a user key fails with class
#' `zv_zr_service_only`. Short rate-limit waits are retried; long ones are
#' reported with the time to wait.
#'
#' @param client A [zr_client()].
#' @param path Route path (see Details).
#' @param query Named list of query parameters.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds (`0` = off, `Inf` = permanent).
#' @param ... For the typed wrappers, further arguments forwarded to `zr_get()`.
#' @return A tibble, parsed list, or httr2 response.
#' @examples
#' \dontrun{
#' zr <- zr_client()
#' zr_get(zr, "/api/public/riders/1234567")
#' zr_rider(zr, 1234567)
#' zr_riders(zr, c(1234567, 2345678))        # one POST for up to 1000 riders
#' }
#' @export
zr_get <- function(client, path, query = list(), parse = "tbl", ttl = .zv_ttl("zr")) {
  stopifnot(inherits(client, "zr_client"))
  if (.zr_is_service(client) && !grepl("^/api/", path)) path <- paste0("/api/v2", path)
  req <- .zr_req(client, path)
  if (length(query)) req <- req_url_query(req, !!!query)
  .zr_fetch(req, parse, ttl, client, .zr_route(path, "GET"))
}

# POST a JSON body (the batch rider lookup). Cached like a GET: the cache key
# includes the body.
.zr_post <- function(client, path, body, parse = "tbl", ttl = .zv_ttl("zr")) {
  req <- .zr_req(client, path, method = "POST") |> req_body_json(body) |> req_method("POST")
  .zr_fetch(req, parse, ttl, client, .zr_route(path, "POST"))
}

# ---- riders ------------------------------------------------------------------

#' @describeIn zr_get A rider's profile: vELO rating (`velo$race`, with
#'   `velo$factors`, `velo$category`), race counts, power bests (`power$w5` ...
#'   `power$w1200`, and w/kg), zFTP, phenotype and club. With `time` (POSIXct or
#'   Unix seconds; user keys only), a snapshot at that moment. Only the legacy
#'   ZwiftRacing rating (`race$current`) is rewound: vELO, power bests and race
#'   counts are always current (checked live, 2026-11).
#' @param zwift_id Zwift rider id.
#' @param time Optional point in time for a historical snapshot.
#' @export
zr_rider <- function(client, zwift_id, time = NULL, ...) {
  if (.zr_is_service(client)) {
    if (!is.null(time)) rlang::abort("`time` snapshots need a user key.")
    return(zr_get(client, sprintf("/api/v2/riders/%s", zwift_id), ...))
  }
  zr_get(client, paste0("/api/public/riders/", zwift_id, .zr_time_seg(time)), ...)
}

.zr_time_seg <- function(time) {
  if (is.null(time)) return("")
  paste0("/", format(as.numeric(time), scientific = FALSE))
}

#' @describeIn zr_get Several riders' profiles, one row each. With a user key
#'   this is one POST per 1000 riders (`time` gives snapshots, as for
#'   `zr_rider()`); with a service
#'   key, one request per rider. Riders that are unknown or opted out are
#'   simply absent.
#' @param ids Vector of Zwift rider ids.
#' @export
zr_riders <- function(client, ids, time = NULL, ...) {
  ids <- unique(as.integer(ids))
  if (.zr_is_service(client)) {
    out <- lapply(ids, function(id) tryCatch(zr_rider(client, id, ...), error = function(e) {
      warning(sprintf("zr_riders: rider %s skipped (%s)", id,
                      strsplit(conditionMessage(e), "\n")[[1]][1]), call. = FALSE)
      NULL
    }))
    return(dplyr::bind_rows(out))
  }
  chunks <- split(ids, ceiling(seq_along(ids) / .ZR_BATCH_MAX))
  .zv_bind(lapply(chunks, function(ch)
    .zr_post(client, paste0("/api/public/riders", .zr_time_seg(time)), as.list(ch), ...)))
}

#' @describeIn zr_get Rider overview, including the legacy ZwiftRacing ratings
#'   (`legacyRatings$live/max30/max90`) and rating history. Service key only.
#' @export
zr_rider_overview <- function(client, zwift_id, ...) {
  .zr_need_service(client, "zr_rider_overview")
  zr_get(client, sprintf("/api/v2/riders/%s/overview", zwift_id), ...)
}

#' @describeIn zr_get A rider's race results over the last `days` days (90 or
#'   365). One row per race (nested `event`, `place`, `race`, `velo`, `legacy`
#'   objects, flattened to dotted column names). Service key only.
#' @param days Look-back window in days.
#' @export
zr_rider_results <- function(client, zwift_id, days = 365, parse = "tbl", ttl = .zv_ttl("zr")) {
  .zr_need_service(client, "zr_rider_results")
  j <- zr_get(client, sprintf("/api/v2/riders/%s/results", zwift_id), query = list(days = days),
              parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  .zv_to_tbl(j$data$results %||% list())
}

#' @describeIn zr_get A rider's ranking / points over the last `days` days.
#'   Service key only.
#' @export
zr_rider_ranking <- function(client, zwift_id, days = 90, ...) {
  .zr_need_service(client, "zr_rider_ranking")
  zr_get(client, sprintf("/api/v2/riders/%s/ranking", zwift_id), query = list(days = days), ...)
}

#' @describeIn zr_get A rider's vELO rating history over the last `days` days.
#'   Service key only.
#' @export
zr_rider_velo <- function(client, zwift_id, days = 365, ...) {
  .zr_need_service(client, "zr_rider_velo")
  zr_get(client, sprintf("/api/v2/riders/%s/velo", zwift_id), query = list(days = days), ...)
}

#' @describeIn zr_get A rider's power curve, efforts and FTP estimate. Service
#'   key only (a user key's `zr_rider()` carries the 5 s - 20 min bests).
#' @export
zr_rider_power <- function(client, zwift_id, ...) {
  .zr_need_service(client, "zr_rider_power")
  zr_get(client, sprintf("/api/v2/riders/%s/power", zwift_id), ...)
}

# ---- events ------------------------------------------------------------------

#' @describeIn zr_get Event metadata (route, distance, pens with summary
#'   stats). Service key only.
#' @param event_id Zwift event id.
#' @export
zr_event <- function(client, event_id, ...) {
  .zr_need_service(client, "zr_event")
  zr_get(client, sprintf("/api/v2/events/%s", event_id), ...)
}

#' @describeIn zr_get Race results for an event, one row per rider. With a
#'   service key this flattens the v2 event's pens and adds a `pen` column
#'   (`position`, `category`, `time`, `wkg*`, ratings, `power.CP`,
#'   `power.AWC`, ...). With a user key it reads `/api/public/results/:id` and
#'   returns its records as they come; that route is for event organisers
#'   only, not Hobby keys.
#' @export
zr_result <- function(client, event_id, parse = "tbl", ttl = .zv_ttl("zr")) {
  if (!.zr_is_service(client)) {
    j <- zr_get(client, sprintf("/api/public/results/%s", event_id),
                parse = if (parse == "tbl") "json" else parse, ttl = ttl)
    if (parse != "tbl") return(j)
    return(.zr_records(j))
  }
  j <- zr_get(client, sprintf("/api/v2/events/%s", event_id),
              parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  pens <- j$data$pens
  if (is.null(pens) || !NROW(pens)) return(tibble::tibble())
  rows <- lapply(seq_len(NROW(pens)), function(i) {
    r <- pens$riders[[i]]
    if (is.null(r) || !NROW(r)) return(NULL)
    tibble::add_column(tibble::as_tibble(r), pen = pens$name[[i]], .before = 1)
  })
  dplyr::bind_rows(rows)
}

#' @describeIn zr_get ZwiftPower's view of an event's results, as served by
#'   ZwiftRacing.app (`/api/public/zp/:id/results`). Organiser keys only.
#' @export
zr_zp_result <- function(client, event_id, parse = "tbl", ttl = .zv_ttl("zr")) {
  j <- zr_get(client, sprintf("/api/public/zp/%s/results", event_id),
              parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  .zr_records(j)
}

# Public routes answer with a bare array, or an object holding one (`data`,
# `results`, `riders`). Return the records as a tibble.
.zr_records <- function(j) {
  if (inherits(j, "data.frame")) return(tibble::as_tibble(j))
  if (is.list(j) && !is.null(names(j))) {
    for (k in c("data", "results", "riders")) {
      if (inherits(j[[k]], "data.frame")) return(tibble::as_tibble(j[[k]]))
    }
  }
  .zv_to_tbl(j)
}

# ---- clubs / misc --------------------------------------------------------------

#' @describeIn zr_get Club summary. With a user key this is
#'   `/api/public/clubs/:id`: `clubId`, `name` and the first 1,000 riders that
#'   have power data. An unknown club comes back with `clubId` and `name`
#'   `NULL` and no riders.
#' @param club_id Club id.
#' @export
zr_club <- function(client, club_id, ...) {
  path <- if (.zr_is_service(client)) "/api/v2/clubs/%s" else "/api/public/clubs/%s"
  zr_get(client, sprintf(path, club_id), ...)
}

#' @describeIn zr_get Club members with ratings (only riders with power data).
#'   Service keys page by number (50 riders a page, 0-indexed; `page = NULL`
#'   fetches all). User keys page by rider id: `/api/public/clubs/:id/:riderId`
#'   returns up to 1,000 riders from that id up, sorted by id. `page = NULL`
#'   follows those pages to the end; otherwise `page` is the rider id to start
#'   from (`0` for the first page). The club route allows one request every
#'   10 minutes, so a club of more than 1,000 riders stops with the wait.
#' @param page Page number (service key) or rider id to start from (user
#'   key), or `NULL` for every page.
#' @export
zr_club_riders <- function(client, club_id, page = NULL, ...) {
  if (!.zr_is_service(client)) return(.zr_club_riders_public(client, club_id, page, ...))
  one <- function(p) zr_get(client, sprintf("/api/v2/clubs/%s/riders", club_id),
                            query = list(page = p), ...)
  if (!is.null(page)) return(one(page))
  out <- list(); p <- 0
  repeat {
    x <- one(p)
    if (!inherits(x, "data.frame") || !nrow(x)) break
    out[[length(out) + 1]] <- x
    if (nrow(x) < 50 || p >= 200) break
    p <- p + 1
  }
  dplyr::bind_rows(out)
}

.zr_club_riders_public <- function(client, club_id, page, ...) {
  one <- function(after) {
    path <- if (is.null(after) || identical(as.numeric(after), 0))
      sprintf("/api/public/clubs/%s", club_id) else sprintf("/api/public/clubs/%s/%s", club_id, after)
    j <- zr_get(client, path, parse = "json", ...)
    .zr_records(j$riders %||% list())
  }
  if (!is.null(page)) return(one(page))
  out <- list(); after <- 0; size <- NULL   # `after`: first rider id of the next page
  repeat {
    x <- one(after)
    if (!NROW(x) || !"riderId" %in% names(x)) break
    out[[length(out) + 1]] <- x
    size <- size %||% nrow(x)                 # the first page sets the page size
    if (nrow(x) < size || length(out) >= 200) break
    after <- max(as.numeric(x$riderId)) + 1   # the start id is inclusive
  }
  .zv_bind(out)
}

#' @describeIn zr_get The vELO category bands (number, name, min, max) on the
#'   1-1000 scale. Organiser keys only.
#' @export
zr_categories <- function(client, ...)
  zr_get(client, "/api/v2/public/categories", ...)

#' @describeIn zr_get How much each ability (endurance, pursuit, sprint, punch,
#'   climb, time trial) counts on a route, for a number of `laps` or a
#'   `distance` in metres (give one). Organiser keys only.
#' @param route_id Zwift route id.
#' @param laps,distance Laps, or distance in metres (exactly one).
#' @param event_type `"race"` (default) or `"timeTrial"`.
#' @export
zr_route_weights <- function(client, route_id, laps = NULL, distance = NULL,
                             event_type = c("race", "timeTrial"), ...) {
  event_type <- match.arg(event_type)
  if (is.null(laps) == is.null(distance)) rlang::abort("Give exactly one of `laps` or `distance`.")
  q <- list(laps = laps, distance = distance, eventType = event_type)
  zr_get(client, sprintf("/api/v2/public/routes/%s/factor-weights", route_id),
         query = q[!vapply(q, is.null, logical(1))], ...)
}

#' @describeIn zr_get Route catalogue. Service key only.
#' @export
zr_routes <- function(client, ...) {
  .zr_need_service(client, "zr_routes")
  zr_get(client, "/api/v2/routes", ...)
}
