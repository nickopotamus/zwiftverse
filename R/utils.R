# JSON -> tibble helpers ------------------------------------------------------
# Arrays of records arrive as data.frames (via jsonlite simplification); single
# objects become one-row tibbles with nested fields kept as list-columns;
# {"data":[...]} envelopes (ZwiftPower cache3) are unwrapped.

.zv_need <- function(pkgs) {
  miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(miss)) {
    stop("Missing packages: ", paste(miss, collapse = ", "),
         ". Install with install.packages(c(",
         paste0('"', miss, '"', collapse = ", "), "))", call. = FALSE)
  }
  invisible(TRUE)
}

.zv_one_row <- function(x) {
  if (!is.list(x)) x <- as.list(x)
  if (!length(x)) return(tibble::tibble())
  cols <- lapply(x, function(v) {
    if (is.null(v)) NA
    else if (length(v) == 1 && !is.list(v)) v
    else list(v)                     # nested object/array -> list-column
  })
  tibble::as_tibble(cols)
}

.zv_rows <- function(lst) {
  if (!length(lst)) return(tibble::tibble())
  dplyr::bind_rows(lapply(lst, .zv_one_row))
}

.zv_to_tbl <- function(parsed) {
  if (inherits(parsed, "data.frame")) return(tibble::as_tibble(parsed))
  if (is.list(parsed) && !is.null(parsed[["data"]])) {
    d <- parsed[["data"]]
    if (inherits(d, "data.frame")) return(tibble::as_tibble(d))
    if (is.list(d) && is.null(names(d))) return(.zv_rows(d))
  }
  if (is.list(parsed) && is.null(names(parsed)) && length(parsed)) return(.zv_rows(parsed))
  .zv_one_row(parsed)
}
