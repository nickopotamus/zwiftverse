# Live smoke test against all three APIs.
#   Rscript dev/smoke-live.R            (from the package root)
# Calls each endpoint you have credentials/ids for (see dev/endpoints.R), and
# reports status, timing, top-level JSON shape, field names and the tibble shape
# .zv_to_tbl() produces. Prints NO values - safe to paste into an issue.
# A full report is written to dev/output/smoke-<timestamp>.md (gitignored).

source("dev/endpoints.R")
options(zwiftverse.cache = FALSE)

.shape <- function(x) {
  if (is.list(x) && is.null(names(x))) {
    first <- if (length(x)) x[[1]] else NULL
    list(kind = sprintf("array[%d]", length(x)),
         fields = if (is.list(first) && !is.null(names(first))) names(first) else character())
  } else if (is.list(x)) {
    if (!is.null(x$data) && is.list(x$data) && is.null(names(x$data))) {
      first <- if (length(x$data)) x$data[[1]] else NULL
      list(kind = sprintf("{data: array[%d]} + %s", length(x$data),
                          paste(setdiff(names(x), "data"), collapse = ",")),
           fields = if (is.list(first)) names(first) else character())
    } else list(kind = "object", fields = names(x))
  } else list(kind = class(x)[1], fields = character())
}

.nested <- function(x, prefix = "", depth = 0) {
  # dotted paths to nested object fields (depth <= 3), for hoist() planning
  if (!is.list(x) || is.null(names(x)) || depth > 3) return(character())
  unlist(lapply(names(x), function(n) {
    p <- if (nzchar(prefix)) paste0(prefix, "$", n) else n
    v <- x[[n]]
    if (is.list(v) && !is.null(names(v))) c(p, .nested(v, p, depth + 1)) else p
  }))
}

h <- zv_dev_handles()
cat(sprintf("Credentials: ZR=%s  Zwift=%s  ZP=%s  rider_id=%s\n\n",
            !is.null(h$zr), !is.null(h$zwift), !is.null(h$zp),
            if (is.null(h$rider_id)) "unset" else "set"))

dir.create("dev/output", showWarnings = FALSE, recursive = TRUE)
rep_path <- file.path("dev/output", format(Sys.time(), "smoke-%Y%m%d-%H%M%S.md"))
R <- new.env(); R$lines <- c("# zwiftverse live smoke test", format(Sys.time()), "")
results <- list()

for (s in zv_dev_specs()) {
  label <- sprintf("%-5s %-11s", s$api, s$name)
  why <- zv_dev_runnable(s, h)
  if (!is.null(why)) { cat(label, " SKIP  (", why, ")\n", sep = ""); 
    results[[length(results) + 1]] <- data.frame(api = s$api, endpoint = s$name, status = "SKIP", note = why)
    next }
  t0 <- Sys.time()
  out <- tryCatch({
    resp <- s$call(h)
    ms <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")) * 1000)
    raw <- httr2::resp_body_json(resp, check_type = FALSE, simplifyVector = FALSE)
    sh <- .shape(raw)
    parsed <- httr2::resp_body_json(resp, check_type = FALSE, simplifyVector = TRUE, simplifyDataFrame = TRUE, flatten = TRUE, bigint_as_char = TRUE)
    tbl <- zwiftverse:::.zv_to_tbl(parsed)
    listcols <- names(tbl)[vapply(tbl, is.list, logical(1))]
    obj <- if (sh$kind == "object") raw else if (is.null(names(raw)) && length(raw)) raw[[1]] else
      if (!is.null(raw$data) && length(raw$data)) raw$data[[1]] else NULL
    cat(label, sprintf(" OK    HTTP %d  %5d ms  %-22s tbl %d x %d\n",
                       httr2::resp_status(resp), ms, sh$kind, nrow(tbl), ncol(tbl)), sep = "")
    R$lines <- c(R$lines, sprintf("## %s / %s", s$api, s$name), "",
              sprintf("- HTTP %d, %d ms, `%s`", httr2::resp_status(resp), ms,
                      httr2::resp_content_type(resp)),
              sprintf("- JSON: %s", sh$kind),
              sprintf("- tibble: %d x %d", nrow(tbl), ncol(tbl)),
              sprintf("- list-columns: %s", if (length(listcols)) paste0("`", listcols, "`", collapse = ", ") else "none"),
              "", "Fields:", "", paste0("    ", paste(sh$fields, collapse = ", ")), "",
              "Nested paths (first record):", "",
              paste0("    ", paste(.nested(obj), collapse = "\n    ")), "")
    data.frame(api = s$api, endpoint = s$name, status = "OK",
               note = sprintf("HTTP %d, %s, tbl %dx%d", httr2::resp_status(resp), sh$kind, nrow(tbl), ncol(tbl)))
  }, error = function(e) {
    msg <- gsub("[\r\n]+", " ", substr(conditionMessage(e), 1, 200))
    cat(label, " FAIL  ", msg, "\n", sep = "")
    R$lines <- c(R$lines, sprintf("## %s / %s", s$api, s$name), "", paste("**FAIL:**", msg), "")
    data.frame(api = s$api, endpoint = s$name, status = "FAIL", note = msg)
  })
  results[[length(results) + 1]] <- out
}

res <- do.call(rbind, results)
writeLines(R$lines, rep_path)
cat(sprintf("\n%d OK, %d FAIL, %d SKIP.  Field report: %s\n",
            sum(res$status == "OK"), sum(res$status == "FAIL"), sum(res$status == "SKIP"), rep_path))
