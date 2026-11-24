# On-disk TTL cache -----------------------------------------------------------
# Caches the *parsed* JSON (parse-independent) keyed on method + URL + body, so
# "tbl" and "json" share one entry. parse = "resp" and POST actions bypass it.
#
# TTL semantics (seconds):
#   0    -> do not cache (always fetch fresh, store nothing)
#   Inf  -> cache permanently (immutable data: completed results)
#   n    -> serve from cache if the entry is younger than n seconds
#
# Controlled by options():
#   zwiftverse.cache      TRUE/FALSE master switch           (default TRUE)
#   zwiftverse.cache_dir  cache location                     (default R_user_dir)
#   zwiftverse.cache_memory  also keep entries in memory for   (default TRUE)
#                         this R session, skipping the disk read on repeat hits
#   zwiftverse.ttl_zwift  Zwift game API default TTL          (default 900)
#   zwiftverse.ttl_zp     ZwiftPower default TTL              (default 3600)
#   zwiftverse.ttl_zr     ZwiftRacing.app default TTL         (default 3600)

#' Is caching currently enabled?
#'
#' Responses are cached as parsed JSON, keyed on method + URL + body, with a
#' per-call time-to-live (`ttl`: `0` = off, `Inf` = permanent, else seconds).
#' Entries live on disk in [zv_cache_dir()] and, within an R session, in
#' memory too, so repeated hits skip the disk read. Options:
#'
#' * `zwiftverse.cache` — master switch (default `TRUE`).
#' * `zwiftverse.cache_dir` — cache location (default `tools::R_user_dir()`).
#' * `zwiftverse.cache_memory` — keep the in-session memory copy (default
#'   `TRUE`; set `FALSE` to bound memory when pulling many large payloads).
#' * `zwiftverse.ttl_zwift`, `zwiftverse.ttl_zp`, `zwiftverse.ttl_zr` —
#'   default TTLs (900, 3600, 3600 seconds).
#' @return Logical scalar.
#' @examples
#' zv_cache_enabled()
#' old <- options(zwiftverse.cache = FALSE)   # turn caching off for a while
#' zv_cache_enabled()
#' options(old)
#' @export
zv_cache_enabled <- function() isTRUE(getOption("zwiftverse.cache", TRUE))

#' Path to the cache directory (created on demand).
#' @return A length-one character path.
#' @examples
#' zv_cache_dir()
#' @export
zv_cache_dir <- function() {
  getOption("zwiftverse.cache_dir",
            tools::R_user_dir("zwiftverse", "cache"))
}

.zv_ttl <- function(api) {
  getOption(paste0("zwiftverse.ttl_", api),
            switch(api, zwift = 900, zp = 3600, zr = 3600, 0))
}

.zv_key <- function(req) {
  rlang::hash(list(
    url    = req$url,
    method = req$method %||% (if (is.null(req$body)) "GET" else "POST"),
    body   = req$body$data
  ))
}

.zv_cache_fresh <- function(url, ttl) {
  if (!zv_cache_enabled() || identical(ttl, 0)) return(FALSE)
  !is.null(.zv_cache_get(.zv_key(request(url)), ttl))
}

.zv_cache_path <- function(key) file.path(zv_cache_dir(), paste0(key, ".rds"))

# In-session layer over the disk cache: path -> list(time, value). `time` is
# when the entry was written, so TTLs behave exactly as on disk.
.zv_mem <- new.env(parent = emptyenv())
.zv_mem_on <- function() isTRUE(getOption("zwiftverse.cache_memory", TRUE))
.zv_fresh <- function(time, ttl) !is.finite(ttl) || as.numeric(Sys.time()) - time <= ttl

.zv_cache_get <- function(key, ttl) {
  p <- .zv_cache_path(key)
  if (.zv_mem_on() && !is.null(m <- .zv_mem[[p]])) {
    if (.zv_fresh(m$time, ttl)) return(m$value)
    return(NULL)
  }
  if (!file.exists(p)) return(NULL)
  time <- as.numeric(file.mtime(p))
  if (!.zv_fresh(time, ttl)) return(NULL)
  value <- tryCatch(readRDS(p), error = function(e) NULL)
  if (!is.null(value) && .zv_mem_on()) .zv_mem[[p]] <- list(time = time, value = value)
  value
}

.zv_cache_set <- function(key, value) {
  dir <- zv_cache_dir()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  p <- .zv_cache_path(key)
  saveRDS(value, p)
  if (.zv_mem_on()) .zv_mem[[p]] <- list(time = as.numeric(Sys.time()), value = value)
  invisible(value)
}

# Core fetch used by every low-level accessor. Builds nothing - takes a ready
# httr2 request, performs it (or serves cache), returns tbl/json/resp.
.zv_fetch <- function(req, parse = c("tbl", "json", "resp"), ttl = 0) {
  parse <- match.arg(parse)
  if (parse == "resp") return(req_perform(req))

  do_cache <- zv_cache_enabled() && !identical(ttl, 0)
  key <- NULL
  if (do_cache) {
    key <- .zv_key(req)
    hit <- .zv_cache_get(key, ttl)
    if (!is.null(hit)) return(if (parse == "json") hit else .zv_to_tbl(hit))
  }

  # check_type = FALSE: ZwiftPower api3.php serves JSON as text/html.
  # bigint_as_char: Zwift activity ids exceed 2^53 and would lose precision.
  # An empty body (ZwiftPower's answer when there is no data) parses as list().
  resp <- req_perform(req)
  parsed <- if (!resp_has_body(resp)) list() else
    resp_body_json(resp, check_type = FALSE,
                   simplifyVector = TRUE, simplifyDataFrame = TRUE,
                   flatten = TRUE, bigint_as_char = TRUE)
  if (do_cache) .zv_cache_set(key, parsed)
  if (parse == "json") parsed else .zv_to_tbl(parsed)
}

#' Clear the cache.
#'
#' Removes every entry on disk and the in-session memory copy (see the
#' `zwiftverse.cache_memory` option in [zv_cache_enabled()]).
#' @return Invisibly, the number of cache files removed.
#' @examples
#' \dontrun{
#' zv_cache_clear()   # wipes every cached response
#' }
#' @export
zv_cache_clear <- function() {
  rm(list = ls(.zv_mem, all.names = TRUE), envir = .zv_mem)
  dir <- zv_cache_dir()
  files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files)) unlink(files)
  invisible(length(files))
}

#' Summarise the cache contents.
#' @return A tibble: one row per cached entry (key, bytes, modified).
#' @examples
#' info <- zv_cache_info()
#' nrow(info)          # number of cached responses
#' sum(info$bytes)     # disk used
#' @export
zv_cache_info <- function() {
  dir <- zv_cache_dir()
  files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
  if (!length(files)) return(tibble::tibble(key = character(), bytes = numeric(),
                                            modified = as.POSIXct(character())))
  tibble::tibble(
    key      = sub("\\.rds$", "", basename(files)),
    bytes    = file.size(files),
    modified = file.mtime(files)
  )
}
