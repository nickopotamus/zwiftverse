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
#   zwiftverse.ttl_zwift  Zwift game API default TTL          (default 900)
#   zwiftverse.ttl_zp     ZwiftPower default TTL              (default 3600)
#   zwiftverse.ttl_zr     ZwiftRacing.app default TTL         (default 3600)

#' Is caching currently enabled?
#' @return Logical scalar.
#' @export
zv_cache_enabled <- function() isTRUE(getOption("zwiftverse.cache", TRUE))

#' Path to the cache directory (created on demand).
#' @return A length-one character path.
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

.zv_cache_get <- function(key, ttl) {
  p <- .zv_cache_path(key)
  if (!file.exists(p)) return(NULL)
  if (is.finite(ttl)) {
    age <- as.numeric(Sys.time()) - as.numeric(file.mtime(p))
    if (age > ttl) return(NULL)
  }
  tryCatch(readRDS(p), error = function(e) NULL)
}

.zv_cache_set <- function(key, value) {
  dir <- zv_cache_dir()
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(value, .zv_cache_path(key))
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

#' Clear the on-disk cache.
#' @return Invisibly, the number of cache files removed.
#' @export
zv_cache_clear <- function() {
  dir <- zv_cache_dir()
  files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(files)) unlink(files)
  invisible(length(files))
}

#' Summarise the cache contents.
#' @return A tibble: one row per cached entry (key, bytes, modified).
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
