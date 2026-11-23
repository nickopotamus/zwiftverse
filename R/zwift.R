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

#' @describeIn zwift_get A rider's activities (paged).
#' @param start,limit Paging offset and page size.
#' @export
zwift_activities <- function(auth, rider_id = "me", start = 0, limit = 20, ...)
  zwift_get(auth, sprintf("/api/profiles/%s/activities/", rider_id),
            query = list(start = start, limit = limit), ...)

#' @describeIn zwift_get A single activity by id.
#' @param activity_id Zwift activity id.
#' @export
zwift_activity <- function(auth, activity_id, ...)
  zwift_get(auth, sprintf("/api/activities/%s", activity_id), ...)

#' @describeIn zwift_get A rider's followers.
#' @export
zwift_followers <- function(auth, rider_id = "me", start = 0, limit = 200, ...)
  zwift_get(auth, sprintf("/api/profiles/%s/followers", rider_id),
            query = list(start = start, limit = limit), ...)

#' @describeIn zwift_get A rider's followees.
#' @export
zwift_followees <- function(auth, rider_id = "me", start = 0, limit = 200, ...)
  zwift_get(auth, sprintf("/api/profiles/%s/followees", rider_id),
            query = list(start = start, limit = limit), ...)

#' @describeIn zwift_get Ride Ons on an activity.
#' @export
zwift_rideons <- function(auth, rider_id, activity_id, ...)
  zwift_get(auth, sprintf("/api/profiles/%s/activities/%s/rideon", rider_id, activity_id), ...)

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
