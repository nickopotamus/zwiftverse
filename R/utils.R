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
  # {"data": ...} envelopes: ZwiftPower cache3 ({data: [...]}) and
  # ZwiftRacing v2 ({success: true, data: [...] | {...}}).
  if (is.list(parsed) && !inherits(parsed, "data.frame") && !is.null(parsed[["data"]])) {
    d <- parsed[["data"]]
    if (inherits(d, "data.frame")) return(tibble::as_tibble(d))
    if (is.list(d) && is.null(names(d))) return(.zv_rows(d))
    if (!is.null(parsed[["success"]]) && is.list(d)) return(.zv_one_row(d))
  }
  if (is.list(parsed) && is.null(names(parsed)) && length(parsed)) return(.zv_rows(parsed))
  .zv_one_row(parsed)
}

# Row-bind pages whose columns may disagree in type (e.g. a field that is all-NA
# logical on one page and character on the next). Conflicting atomic columns are
# coerced to character; anything else becomes a list-column.
.zv_bind <- function(pieces) {
  pieces <- Filter(function(p) !is.null(p) && NROW(p) > 0, pieces)
  if (!length(pieces)) return(tibble::tibble())
  out <- tryCatch(dplyr::bind_rows(pieces), error = function(e) NULL)
  if (!is.null(out)) return(out)
  cols <- unique(unlist(lapply(pieces, names)))
  for (cn in cols) {
    cls <- unique(unlist(lapply(pieces, function(p) if (cn %in% names(p)) class(p[[cn]])[1])))
    if (length(cls) < 2) next
    all_atomic <- all(vapply(pieces, function(p) !(cn %in% names(p)) || is.atomic(p[[cn]]), logical(1)))
    pieces <- lapply(pieces, function(p) {
      if (!cn %in% names(p)) return(p)
      p[[cn]] <- if (all_atomic) as.character(p[[cn]]) else as.list(p[[cn]])
      p
    })
  }
  dplyr::bind_rows(pieces)
}

# Generic start/limit pager. `fetch(start, n)` returns parsed JSON for one page;
# `extract` pulls the record array out of it. Fetches until `limit` rows are
# collected or a short page signals the end.
.zv_paged <- function(fetch, start = 0, limit = Inf, page_max = 50,
                      extract = identity) {
  pieces <- list(); got <- 0; pos <- start
  repeat {
    n <- min(page_max, limit - got)
    if (n <= 0) break
    page <- .zv_to_tbl(extract(fetch(pos, n)) %||% list())
    if (NROW(page)) pieces[[length(pieces) + 1]] <- page
    got <- got + NROW(page); pos <- pos + n
    if (NROW(page) < n) break
  }
  .zv_bind(pieces)
}

# Error-body extractor for req_error(): an error response may have no body
# (e.g. a bare 401), which resp_body_string() would turn into a parse error
# that hides the real HTTP status.
.zv_err_body <- function(resp) {
  if (!resp_has_body(resp)) return(NULL)
  substr(resp_body_string(resp), 1, 500)
}

# The one user-agent for every request: says what we are and where to find us.
.zv_ua <- function() sprintf("zwiftverse/%s (+https://github.com/nickopotamus/zwiftverse)",
                             utils::packageVersion("zwiftverse"))
