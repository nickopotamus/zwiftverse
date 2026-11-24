# Zwift game API --------------------------------------------------------------
# Auth:   POST secure.zwift.com/auth/realms/zwift/tokens/access/codes
#         grant_type=password, client_id=Zwift_Mobile_Link
# Base:   https://us-or-rly101.zwift.com   Header: Authorization: Bearer <token>
# Scope:  your own + any rider's PUBLIC profile/activities, live world rosters,
#         events. Personal data is GDPR-consent-gated.

# Legacy Keycloak path first (long-standing community value), then the standard
# OpenID Connect token endpoint as a fallback if Zwift retires the old one.
# Override with options(zwiftverse.zwift_auth_url = "...").
.ZWIFT_AUTH_URLS <- c(
  "https://secure.zwift.com/auth/realms/zwift/tokens/access/codes",
  "https://secure.zwift.com/auth/realms/zwift/protocol/openid-connect/token"
)
.ZWIFT_CLIENT   <- "Zwift_Mobile_Link"
.ZWIFT_BASE     <- "https://us-or-rly101.zwift.com"
.ZWIFT_UA       <- "Zwift/115 CFNetwork/758.0.2 Darwin/15.0.0"

#' Authenticate against the Zwift game API
#'
#' Performs an OAuth2 password-grant login and returns a handle that refreshes
#' the access token automatically. Requires your own Zwift credentials.
#'
#' Token handling:
#'
#' * Expiry times are measured from when the token *request was sent*, and a
#'   token is renewed early (10% of its lifetime, 5–60 s), so slow responses
#'   and modest clock skew don't produce expired tokens.
#' * When the access token expires the refresh token is used; if Zwift
#'   rejects the refresh (expired or revoked server-side), the handle logs in
#'   again with the password instead of failing.
#' * A `refresh_expires_in` of `0` (a Keycloak offline token) never expires.
#' * If the API answers `401` to a token the handle still thought valid,
#'   [zwift_get()] / [zwift_post()] discard it and retry the request once.
#'
#' The handle exposes `token()`, `login()`, `refresh()` and `invalidate()`;
#' printing it shows token status only, never the token or credentials.
#'
#' @param username,password Zwift account credentials. Default to the
#'   environment variables `ZWIFT_USERNAME` / `ZWIFT_PASSWORD`.
#' @return An object of class `zwift_auth`.
#' @examples
#' \dontrun{
#' za <- zwift_auth()   # credentials from ZWIFT_USERNAME / ZWIFT_PASSWORD
#' za                   # token status, never the token itself
#' zwift_profile(za)
#' }
#' @export
zwift_auth <- function(username = Sys.getenv("ZWIFT_USERNAME"),
                       password = Sys.getenv("ZWIFT_PASSWORD")) {
  if (!nzchar(username) || !nzchar(password))
    stop("Set username/password or ZWIFT_USERNAME / ZWIFT_PASSWORD env vars.",
         call. = FALSE)

  st <- new.env(parent = emptyenv())
  st$access <- NULL; st$refresh <- NULL; st$access_exp <- 0; st$refresh_exp <- 0

  urls <- getOption("zwiftverse.zwift_auth_url", .ZWIFT_AUTH_URLS)
  post <- function(body) {
    resp <- NULL
    for (u in urls) {
      resp <- request(u) |>
        req_user_agent(.ZWIFT_UA) |>
        req_body_form(!!!body) |>
        req_retry(max_tries = 3) |>
        req_error(is_error = function(resp) FALSE) |>
        req_perform()
      # 404/405 => endpoint moved; try the next candidate. Anything else is final.
      if (!resp_status(resp) %in% c(404, 405)) break
    }
    resp
  }
  fail <- function(resp)
    stop(sprintf("Zwift auth failed (HTTP %s) at %s: %s", resp_status(resp),
                 resp$url, .zv_err_body(resp) %||% ""), call. = FALSE)
  # Store a token response. `sent` is when the request left, so the expiry is
  # never later than the server's; `early` renews a little before that.
  store <- function(resp, sent) {
    st$auth_url <- resp$url
    tok <- resp_body_json(resp)
    early <- function(life) life - min(60, max(5, 0.1 * life))
    life_a <- as.numeric(tok$expires_in %||% 3600)
    life_r <- as.numeric(tok$refresh_expires_in %||% 1800)
    st$access      <- tok$access_token
    st$refresh     <- tok$refresh_token %||% st$refresh
    st$access_exp  <- sent + early(life_a)
    st$refresh_exp <- if (life_r <= 0) Inf else sent + early(life_r)
    invisible(st)
  }
  login <- function() {
    sent <- as.numeric(Sys.time())
    resp <- post(list(username = username, password = password,
                      grant_type = "password", client_id = .ZWIFT_CLIENT))
    if (resp_is_error(resp)) fail(resp)
    store(resp, sent)
  }
  refresh <- function() {
    if (is.null(st$refresh)) return(login())
    sent <- as.numeric(Sys.time())
    resp <- post(list(grant_type = "refresh_token", refresh_token = st$refresh,
                      client_id = .ZWIFT_CLIENT))
    # 400 invalid_grant / 401: refresh token expired or revoked -> log in again.
    if (resp_status(resp) %in% c(400, 401)) {
      st$refresh <- NULL; st$refresh_exp <- 0
      return(login())
    }
    if (resp_is_error(resp)) fail(resp)
    store(resp, sent)
  }
  invalidate <- function() { st$access_exp <- 0; invisible() }
  token <- function() {
    now <- as.numeric(Sys.time())
    if (!is.null(st$access)  && now < st$access_exp)  return(st$access)
    if (!is.null(st$refresh) && now < st$refresh_exp) refresh() else login()
    st$access
  }
  structure(list(token = token, login = login, refresh = refresh,
                 invalidate = invalidate, .state = st),
            class = "zwift_auth")
}

#' @export
print.zwift_auth <- function(x, ...) {
  st <- x$.state
  left <- function(t) if (is.infinite(t)) "no expiry" else
    sprintf("%s left", format(round(max(0, t - as.numeric(Sys.time()))), big.mark = ","))
  cat("<zwift_auth>\n")
  if (is.null(st$access)) cat("  not logged in yet (first request logs in)\n") else {
    cat(sprintf("  access token:  %s\n", left(st$access_exp)))
    cat(sprintf("  refresh token: %s\n",
                if (is.null(st$refresh)) "none" else left(st$refresh_exp)))
    cat(sprintf("  endpoint:      %s\n", st$auth_url %||% "?"))
  }
  invisible(x)
}

# Perform a Zwift request built by `build(token)`; on a 401 for a token we
# thought valid, discard it and retry once with a fresh one.
.zwift_send <- function(auth, build, parse, ttl) {
  tryCatch(.zv_fetch(build(auth$token()), parse, ttl),
           httr2_http_401 = function(e) {
             if (!is.function(auth$invalidate)) stop(e)
             auth$invalidate()
             .zv_fetch(build(auth$token()), parse, ttl)
           })
}

# Only /api/profiles/me accepts the "me" alias; sub-resources
# (/activities, /followers, ...) need the numeric id. Resolve once per handle.
.zwift_rid <- function(auth, rider_id) {
  if (!identical(as.character(rider_id), "me")) return(rider_id)
  st <- auth$.state
  if (is.environment(st) && !is.null(st$me_id)) return(st$me_id)
  id <- zwift_get(auth, "/api/profiles/me", parse = "json", ttl = 0)$id
  if (is.environment(st)) st$me_id <- id
  id
}

#' Low-level Zwift GET
#'
#' @param auth A [zwift_auth()] handle.
#' @param path Endpoint path, e.g. `"/api/profiles/me"`.
#' @param query Named list of query parameters.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds (`0` = off, `Inf` = permanent).
#' @param ... For the typed wrappers, further arguments forwarded to
#'   `zwift_get()` (e.g. `parse`, `ttl`).
#' @return A tibble, parsed list, or httr2 response.
#' @examples
#' \dontrun{
#' za <- zwift_auth()
#' zwift_get(za, "/api/profiles/me/activities/", list(limit = 5))
#' zwift_get(za, "/api/profiles/me", parse = "json")
#' }
#' @export
zwift_get <- function(auth, path, query = list(), parse = "tbl", ttl = .zv_ttl("zwift")) {
  stopifnot(inherits(auth, "zwift_auth"))
  build <- function(token) {
    req <- request(paste0(.ZWIFT_BASE, path)) |>
      req_headers(Authorization = paste("Bearer", token), Accept = "application/json") |>
      req_user_agent(.ZWIFT_UA) |>
      req_retry(max_tries = 3,
                is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503)) |>
      req_error(body = .zv_err_body)
    if (length(query)) req <- req_url_query(req, !!!query)
    req
  }
  .zwift_send(auth, build, parse, ttl)
}

#' Low-level Zwift POST
#' @inheritParams zwift_get
#' @param body Request body (encoded as JSON). `NULL` (default) sends no body.
#' @return The httr2 response (or parsed JSON / tibble if `parse` says so).
#' @examples
#' \dontrun{
#' za <- zwift_auth()
#' # give a ride-on (what zwift_give_rideon() does)
#' zwift_post(za, "/api/profiles/1234567/activities/987654321/rideon",
#'            body = list())
#' }
#' @export
zwift_post <- function(auth, path, body = NULL, parse = "resp") {
  stopifnot(inherits(auth, "zwift_auth"))
  build <- function(token) {
    req <- request(paste0(.ZWIFT_BASE, path)) |>
      req_headers(Authorization = paste("Bearer", token), Accept = "application/json") |>
      req_user_agent(.ZWIFT_UA) |>
      req_error(body = .zv_err_body)
    if (!is.null(body)) req <- req_body_json(req, body)
    req
  }
  .zwift_send(auth, build, parse, ttl = 0)
}

#' @describeIn zwift_get A rider's profile (`"me"` or a Zwift id).
#' @param rider_id Zwift rider id, or `"me"`.
#' @export
zwift_profile <- function(auth, rider_id = "me", ...)
  zwift_get(auth, sprintf("/api/profiles/%s", rider_id), ...)

# Page sizes the server accepts (larger -> HTTP 400 "limit.too.large"), 2026-11.
.ZWIFT_PAGE <- c(activities = 50, follows = 200, results = 50, entrants = 50)

# Shared list fetcher: one request when `limit` fits in a page (any `parse`),
# otherwise auto-pages and returns one tibble.
.zwift_list <- function(auth, path, start, limit, page_max, parse, ttl,
                        query = list(), extract = identity) {
  if (is.finite(limit) && limit <= page_max) {
    x <- zwift_get(auth, path, query = c(query, list(start = start, limit = limit)),
                   parse = if (parse == "tbl") "json" else parse, ttl = ttl)
    return(if (parse == "tbl") .zv_to_tbl(extract(x) %||% list()) else x)
  }
  if (parse != "tbl")
    stop(sprintf("limit > %d spans several requests; use parse = \"tbl\".", page_max),
         call. = FALSE)
  .zv_paged(function(pos, n) zwift_get(auth, path, query = c(query, list(start = pos, limit = n)),
                                       parse = "json", ttl = ttl),
            start = start, limit = limit, page_max = page_max, extract = extract)
}

#' @describeIn zwift_get A rider's activities, newest first. `limit` is the
#'   total wanted: values above the server's page size (50) are fetched page by
#'   page and bound; `limit = Inf` fetches the whole history.
#' @param start,limit Offset of the first record, and how many records to
#'   return (`Inf` = all). Paging happens automatically.
#' @export
zwift_activities <- function(auth, rider_id = "me", start = 0, limit = 20,
                             parse = "tbl", ttl = .zv_ttl("zwift"))
  .zwift_list(auth, sprintf("/api/profiles/%s/activities", .zwift_rid(auth, rider_id)),
              start, limit, .ZWIFT_PAGE[["activities"]], parse, ttl)

#' @describeIn zwift_get A single activity by id.
#' @param activity_id Zwift activity id.
#' @export
zwift_activity <- function(auth, activity_id, ...)
  zwift_get(auth, sprintf("/api/activities/%s", activity_id), ...)

#' @describeIn zwift_get A rider's followers (auto-paged, 200 per request).
#' @export
zwift_followers <- function(auth, rider_id = "me", start = 0, limit = Inf,
                            parse = "tbl", ttl = .zv_ttl("zwift"))
  .zwift_list(auth, sprintf("/api/profiles/%s/followers", .zwift_rid(auth, rider_id)),
              start, limit, .ZWIFT_PAGE[["follows"]], parse, ttl)

#' @describeIn zwift_get Riders a rider follows (auto-paged, 200 per request).
#' @export
zwift_followees <- function(auth, rider_id = "me", start = 0, limit = Inf,
                            parse = "tbl", ttl = .zv_ttl("zwift"))
  .zwift_list(auth, sprintf("/api/profiles/%s/followees", .zwift_rid(auth, rider_id)),
              start, limit, .ZWIFT_PAGE[["follows"]], parse, ttl)

#' @describeIn zwift_get Ride Ons on an activity.
#' @export
zwift_rideons <- function(auth, rider_id, activity_id, ...)
  zwift_get(auth, sprintf("/api/profiles/%s/activities/%s/rideon", .zwift_rid(auth, rider_id), activity_id), ...)

#' @describeIn zwift_get Give a Ride On (POST). Returns the raw response.
#' @export
zwift_give_rideon <- function(auth, rider_id, activity_id)
  zwift_post(auth, sprintf("/api/profiles/%s/activities/%s/rideon", rider_id, activity_id),
             body = list())

#' @describeIn zwift_get An event by id.
#' @param event_id Zwift event id.
#' @export
zwift_event <- function(auth, event_id, ...)
  zwift_get(auth, sprintf("/api/events/%s", event_id), ...)

#' @describeIn zwift_get An event's subgroups (pens / categories): one row
#'   each, with `id` (the subgroup id used by the results and entrants
#'   functions), `subgroupLabel` (A, B, ...), start time and route.
#' @export
zwift_event_subgroups <- function(auth, event_id, parse = "tbl", ttl = .zv_ttl("zwift")) {
  j <- zwift_event(auth, event_id, parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  .zv_to_tbl(j$eventSubgroups %||% list())
}

#' @describeIn zwift_get Official Zwift race results for one subgroup, in
#'   finishing order (`rank`), auto-paged (50 per request). Nested objects are
#'   flattened: `activityData.*`, `criticalP.*`, `sensorData.*`,
#'   `profileData.*`, `scoreHistory.*`.
#' @param subgroup_id Event subgroup id (from `zwift_event_subgroups()`).
#' @export
zwift_subgroup_results <- function(auth, subgroup_id, start = 0, limit = Inf,
                                   parse = "tbl", ttl = .zv_ttl("zwift"))
  .zwift_list(auth, "/api/race-results/entries", start, limit, .ZWIFT_PAGE[["results"]],
              parse, ttl, query = list(event_subgroup_id = subgroup_id),
              extract = function(x) x$entries)

#' @describeIn zwift_get Race results for every subgroup of an event, bound
#'   into one tibble with a leading `subgroup` label column.
#' @export
zwift_event_results <- function(auth, event_id, ttl = .zv_ttl("zwift"))
  .zwift_by_subgroup(auth, event_id, ttl, function(id)
    zwift_subgroup_results(auth, id, ttl = ttl))

#' @describeIn zwift_get Riders signed up to one subgroup (auto-paged).
#' @param participation Entrant filter passed to the API; `"signed_up"` is the
#'   value verified to work.
#' @export
zwift_subgroup_entrants <- function(auth, subgroup_id, participation = "signed_up",
                                    start = 0, limit = Inf, parse = "tbl",
                                    ttl = .zv_ttl("zwift"))
  .zwift_list(auth, sprintf("/api/events/subgroups/entrants/%s", subgroup_id), start, limit,
              .ZWIFT_PAGE[["entrants"]], parse, ttl,
              query = list(participation = participation, type = "all"))

#' @describeIn zwift_get Sign-ups for every subgroup of an event, with a
#'   leading `subgroup` label column.
#' @export
zwift_event_entrants <- function(auth, event_id, participation = "signed_up",
                                 ttl = .zv_ttl("zwift"))
  .zwift_by_subgroup(auth, event_id, ttl, function(id)
    zwift_subgroup_entrants(auth, id, participation = participation, ttl = ttl))

.zwift_by_subgroup <- function(auth, event_id, ttl, fetch) {
  sg <- zwift_event_subgroups(auth, event_id, ttl = ttl)
  if (!NROW(sg)) return(tibble::tibble())
  .zv_bind(lapply(seq_len(nrow(sg)), function(i) {
    x <- fetch(sg$id[[i]])
    if (!NROW(x)) return(NULL)
    tibble::add_column(x, subgroup = sg$subgroupLabel[[i]], .before = 1)
  }))
}

#' @describeIn zwift_get List of active worlds.
#' @export
zwift_worlds <- function(auth, ...)
  zwift_get(auth, "/relay/worlds", ...)

#' @describeIn zwift_get Roster of riders currently in a world. Live
#'   position/power is protobuf on `/relay/worlds/{id}/players/{id}`; this JSON
#'   endpoint returns the roster only.
#' @param world_id World id (1 = Watopia host world).
#' @export
zwift_riders_in_world <- function(auth, world_id = 1, ...)
  zwift_get(auth, sprintf("/relay/worlds/%s", world_id), ...)
