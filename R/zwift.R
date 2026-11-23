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
#' @param username,password Zwift account credentials. Default to the
#'   environment variables `ZWIFT_USERNAME` / `ZWIFT_PASSWORD`.
#' @return An object of class `zwift_auth`.
#' @export
zwift_auth <- function(username = Sys.getenv("ZWIFT_USERNAME"),
                       password = Sys.getenv("ZWIFT_PASSWORD")) {
  if (!nzchar(username) || !nzchar(password))
    stop("Set username/password or ZWIFT_USERNAME / ZWIFT_PASSWORD env vars.",
         call. = FALSE)

  st <- new.env(parent = emptyenv())
  st$access <- NULL; st$refresh <- NULL; st$access_exp <- 0; st$refresh_exp <- 0

  urls <- getOption("zwiftverse.zwift_auth_url", .ZWIFT_AUTH_URLS)
  grant <- function(body) {
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
    if (resp_is_error(resp))
      stop(sprintf("Zwift auth failed (HTTP %s) at %s: %s", resp_status(resp),
                   resp$url, substr(resp_body_string(resp), 1, 300)), call. = FALSE)
    st$auth_url <- resp$url
    tok <- resp_body_json(resp)
    now <- as.numeric(Sys.time())
    st$access      <- tok$access_token
    st$refresh     <- tok$refresh_token
    st$access_exp  <- now + (tok$expires_in %||% 3600) - 10
    st$refresh_exp <- now + (tok$refresh_expires_in %||% 1800) - 10
    invisible(st)
  }
  login   <- function() grant(list(username = username, password = password,
                                   grant_type = "password", client_id = .ZWIFT_CLIENT))
  refresh <- function() grant(list(grant_type = "refresh_token",
                                   refresh_token = st$refresh, client_id = .ZWIFT_CLIENT))
  token <- function() {
    now <- as.numeric(Sys.time())
    if (!is.null(st$access)  && now < st$access_exp)  return(st$access)
    if (!is.null(st$refresh) && now < st$refresh_exp) { refresh(); return(st$access) }
    login(); st$access
  }
  structure(list(token = token, login = login, refresh = refresh, .state = st),
            class = "zwift_auth")
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
#' @export
zwift_get <- function(auth, path, query = list(), parse = "tbl", ttl = .zv_ttl("zwift")) {
  stopifnot(inherits(auth, "zwift_auth"))
  req <- request(paste0(.ZWIFT_BASE, path)) |>
    req_headers(Authorization = paste("Bearer", auth$token()), Accept = "application/json") |>
    req_user_agent(.ZWIFT_UA) |>
    req_retry(max_tries = 3,
              is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503)) |>
    req_error(body = function(resp) resp_body_string(resp))
  if (length(query)) req <- req_url_query(req, !!!query)
  .zv_fetch(req, parse, ttl)
}

#' Low-level Zwift POST
#' @inheritParams zwift_get
#' @param body Request body (encoded as JSON). Defaults to an empty object.
#' @export
zwift_post <- function(auth, path, body = NULL, parse = "resp") {
  stopifnot(inherits(auth, "zwift_auth"))
  req <- request(paste0(.ZWIFT_BASE, path)) |>
    req_headers(Authorization = paste("Bearer", auth$token()), Accept = "application/json") |>
    req_user_agent(.ZWIFT_UA) |>
    req_error(body = function(resp) resp_body_string(resp))
  if (!is.null(body)) req <- req_body_json(req, body)
  .zv_fetch(req, parse, ttl = 0)
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
