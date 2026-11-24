# ZwiftRacing.app (API v2) ----------------------------------------------------
# Base:  https://api.zwiftracing.app/api/v2
# Auth:  header  x-api-key: <your-key>        (verified live 2026-11-23; the
#        older v1 /public/* routes and `Authorization:` header return 401)
# Responses are wrapped as {"success": true, "data": ...}; the tibble path
# unwraps `data`, parse = "json" returns the envelope untouched.
# Rate-limited; retries on 429 (honouring Retry-After) and 5xx.

.ZR_BASE <- "https://api.zwiftracing.app/api/v2"

#' Create a ZwiftRacing.app client
#'
#' @param auth Your ZwiftRacing.app API key, sent as the `x-api-key` header.
#'   Defaults to the environment variable `ZR_AUTH`.
#' @param rate Throttle in requests per second (default 2; tune to your quota).
#' @return An object of class `zr_client`.
#' @examples
#' \dontrun{
#' zr <- zr_client()                  # key from the ZR_AUTH environment variable
#' zr <- zr_client("your-key", rate = 1)
#' }
#' @export
zr_client <- function(auth = Sys.getenv("ZR_AUTH"), rate = 2) {
  if (!nzchar(auth)) stop("Provide your ZwiftRacing.app key or set ZR_AUTH.", call. = FALSE)
  structure(list(auth = trimws(auth), rate = rate), class = "zr_client")
}

.zr_req <- function(client, path) {
  request(paste0(.ZR_BASE, path)) |>
    req_headers(`x-api-key` = client$auth, Accept = "application/json") |>
    req_user_agent("zwiftverse-r/0.1") |>
    # Token bucket: `rate` req/s averaged over a 60 s window (httr2 >= 1.1 API).
    req_throttle(capacity = max(1L, as.integer(ceiling((client$rate %||% 2) * 60))),
                 fill_time_s = 60) |>
    req_retry(max_tries = 5,
              is_transient = function(resp) resp_status(resp) %in% c(429, 500, 502, 503)) |>
    req_error(body = .zv_err_body)
}

#' Low-level ZwiftRacing.app GET
#'
#' @param client A [zr_client()].
#' @param path Endpoint path under `/api/v2`, e.g. `"/riders/123"`.
#' @param query Named list of query parameters.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds (`0` = off, `Inf` = permanent).
#' @param ... For the typed wrappers, further arguments forwarded to `zr_get()`.
#' @return A tibble, parsed list, or httr2 response.
#' @examples
#' \dontrun{
#' zr <- zr_client()
#' zr_get(zr, "/riders/1234567")
#' zr_get(zr, "/riders/1234567", parse = "json", ttl = 0)  # raw list, no cache
#' }
#' @export
zr_get <- function(client, path, query = list(), parse = "tbl", ttl = .zv_ttl("zr")) {
  stopifnot(inherits(client, "zr_client"))
  req <- .zr_req(client, path)
  if (length(query)) req <- req_url_query(req, !!!query)
  .zv_fetch(req, parse, ttl)
}

# ---- riders ------------------------------------------------------------------

#' @describeIn zr_get A rider's current profile: vELO rating (`velo$race`,
#'   with `velo$factors`), race counts (`race$finishes/wins/podiums/dnfs`),
#'   power, points, phenotype and club.
#' @param zwift_id Zwift rider id.
#' @export
zr_rider <- function(client, zwift_id, ...)
  zr_get(client, sprintf("/riders/%s", zwift_id), ...)

#' @describeIn zr_get Rider overview, including the legacy ZwiftRacing ratings
#'   (`legacyRatings$live/max30/max90`) and rating history.
#' @export
zr_rider_overview <- function(client, zwift_id, ...)
  zr_get(client, sprintf("/riders/%s/overview", zwift_id), ...)

#' @describeIn zr_get A rider's race results over the last `days` days. One row
#'   per race (nested `event`, `place`, `race`, `velo`, `legacy` objects,
#'   flattened to dotted column names).
#' @param days Look-back window in days.
#' @export
zr_rider_results <- function(client, zwift_id, days = 365, parse = "tbl", ttl = .zv_ttl("zr")) {
  j <- zr_get(client, sprintf("/riders/%s/results", zwift_id), query = list(days = days),
              parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  .zv_to_tbl(j$data$results %||% list())
}

#' @describeIn zr_get A rider's ranking / points over the last `days` days.
#' @export
zr_rider_ranking <- function(client, zwift_id, days = 90, ...)
  zr_get(client, sprintf("/riders/%s/ranking", zwift_id), query = list(days = days), ...)

#' @describeIn zr_get A rider's vELO rating history over the last `days` days.
#' @export
zr_rider_velo <- function(client, zwift_id, days = 365, ...)
  zr_get(client, sprintf("/riders/%s/velo", zwift_id), query = list(days = days), ...)

#' @describeIn zr_get A rider's power curve, efforts and FTP estimate.
#' @export
zr_rider_power <- function(client, zwift_id, ...)
  zr_get(client, sprintf("/riders/%s/power", zwift_id), ...)

#' @describeIn zr_get Several riders' profiles, one row each. API v2 has no
#'   batch endpoint, so this makes one (throttled, cached) request per rider;
#'   riders that error (e.g. not found / opted out) are dropped with a warning.
#' @param ids Vector of Zwift rider ids.
#' @export
zr_riders <- function(client, ids, ...) {
  ids <- unique(ids)
  out <- lapply(ids, function(id) tryCatch(zr_rider(client, id, ...), error = function(e) {
    warning(sprintf("zr_riders: rider %s skipped (%s)", id,
                    strsplit(conditionMessage(e), "\n")[[1]][1]), call. = FALSE)
    NULL
  }))
  dplyr::bind_rows(out)
}

# ---- events ------------------------------------------------------------------

#' @describeIn zr_get Event metadata (route, distance, pens with summary stats).
#' @param event_id Zwift event id.
#' @export
zr_event <- function(client, event_id, ...)
  zr_get(client, sprintf("/events/%s", event_id), ...)

#' @describeIn zr_get Race results for an event: one row per rider across all
#'   pens, with a `pen` column. Includes `position`, `category`, `time`,
#'   power (`wkg*`), and ratings (`ratingBefore`, `rating`, `ratingDelta`,
#'   `riderVelo.race`).
#' @export
zr_result <- function(client, event_id, parse = "tbl", ttl = .zv_ttl("zr")) {
  j <- zr_get(client, sprintf("/events/%s", event_id),
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

# ---- clubs / misc --------------------------------------------------------------

#' @describeIn zr_get Club summary (name, colours, rider counts).
#' @param club_id Club id.
#' @export
zr_club <- function(client, club_id, ...)
  zr_get(client, sprintf("/clubs/%s", club_id), ...)

#' @describeIn zr_get Club members with ratings. Pages hold 50 riders and are
#'   0-indexed; `page = NULL` (default) fetches every page and binds them.
#' @param page Page number (0-based), or `NULL` for all pages.
#' @export
zr_club_riders <- function(client, club_id, page = NULL, ...) {
  one <- function(p) zr_get(client, sprintf("/clubs/%s/riders", club_id),
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

#' @describeIn zr_get Route catalogue.
#' @export
zr_routes <- function(client, ...)
  zr_get(client, "/routes", ...)
