# ZwiftRacing.app -------------------------------------------------------------
# Base:  https://api.zwiftracing.app/api
# Auth:  header  Authorization: <your-key>   (raw key, NOT "Bearer")
# Rate-limited; retries on 429. Batch rider POST takes up to 1000 ids.

.ZR_BASE <- "https://api.zwiftracing.app/api"

#' Create a ZwiftRacing.app client
#'
#' @param auth Your ZwiftRacing.app API key (the raw `Authorization` header
#'   value). Defaults to the environment variable `ZR_AUTH`.
#' @param rate Throttle in requests per second (default 2; tune to your quota).
#' @return An object of class `zr_client`.
#' @export
zr_client <- function(auth = Sys.getenv("ZR_AUTH"), rate = 2) {
  if (!nzchar(auth)) stop("Provide your ZwiftRacing.app key or set ZR_AUTH.", call. = FALSE)
  structure(list(auth = auth, rate = rate), class = "zr_client")
}

.zr_req <- function(client, path) {
  request(paste0(.ZR_BASE, path)) |>
    req_headers(Authorization = client$auth, Accept = "application/json") |>
    req_user_agent("zwiftverse-r/0.1") |>
    # Token bucket: `rate` req/s averaged over a 60 s window (httr2 >= 1.1 API).
    req_throttle(capacity = max(1L, as.integer(ceiling((client$rate %||% 2) * 60))),
                 fill_time_s = 60) |>
    req_retry(max_tries = 5,
              is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503)) |>
    req_error(body = function(resp) resp_body_string(resp))
}

#' Low-level ZwiftRacing.app GET
#'
#' @param client A [zr_client()].
#' @param path Endpoint path, e.g. `"/public/riders/123"`.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds (`0` = off, `Inf` = permanent).
#' @param ... For the typed wrappers, further arguments forwarded to `zr_get()`.
#' @return A tibble, parsed list, or httr2 response.
#' @export
zr_get <- function(client, path, parse = "tbl", ttl = .zv_ttl("zr"))
  .zv_fetch(.zr_req(client, path), parse, ttl)

#' Low-level ZwiftRacing.app POST
#' @inheritParams zr_get
#' @param body Request body, encoded as JSON.
#' @export
zr_post <- function(client, path, body, parse = "tbl", ttl = 0)
  .zv_fetch(req_body_json(.zr_req(client, path), body), parse, ttl)

#' @describeIn zr_get A single rider's rating. `epoch` (unix seconds) returns an
#'   immutable historical snapshot - safe to cache with `ttl = Inf`.
#' @param zwift_id Zwift rider id.
#' @param epoch Optional unix timestamp for a historical snapshot.
#' @export
zr_rider <- function(client, zwift_id, epoch = NULL, ...)
  zr_get(client,
         if (is.null(epoch)) sprintf("/public/riders/%s", zwift_id)
         else sprintf("/public/riders/%s/%s", zwift_id, epoch), ...)

#' @describeIn zr_get Batch rider fetch via POST (up to 1000 ids, one request).
#' @param ids Integer vector of Zwift rider ids (<= 1000).
#' @export
zr_riders <- function(client, ids, epoch = NULL, ...) {
  if (length(ids) > 1000) stop("ZR batch endpoint accepts <= 1000 ids per call.", call. = FALSE)
  path <- if (is.null(epoch)) "/public/riders" else sprintf("/public/riders/%s", epoch)
  # Sorted + de-duplicated so {1,2} and {2,1} share one cache entry.
  zr_post(client, path, body = as.list(as.numeric(sort(unique(ids)))), ...)
}

#' @describeIn zr_get Race results for an event id.
#' @param race_id ZwiftRacing event id.
#' @export
zr_result <- function(client, race_id, ...)
  zr_get(client, sprintf("/public/results/%s", race_id), ...)

#' @describeIn zr_get Club / team roster. `offset` is the starting rider index.
#' @param team_id Club id.
#' @param offset Starting rider index (0 = first page).
#' @export
zr_club <- function(client, team_id, offset = 0, ...)
  zr_get(client, sprintf("/public/clubs/%s/%s", team_id, offset), ...)

#' @describeIn zr_get Category definitions (v2 endpoint).
#' @export
zr_categories <- function(client, ...)
  zr_get(client, "/v2/public/categories", ...)
