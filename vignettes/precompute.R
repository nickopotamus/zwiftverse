# Re-render the vignettes from live data. Needs the credentials listed in each
# vignette (ZR_AUTH, ZP_SID, ZWIFT_USERNAME / ZWIFT_PASSWORD).
#
#   Rscript vignettes/precompute.R            # from the package root
#
# Each vignettes/<name>.Rmd.orig is knitted into vignettes/<name>.Rmd with its
# output and figures baked in, so R CMD check, CI and pkgdown never call the
# APIs. Riders are pseudonymised while knitting (anonymise.R); afterwards every
# real rider id, name and team name seen is searched for in the output, and the
# run fails if any is found.

if (basename(getwd()) != "vignettes") setwd("vignettes")
suppressPackageStartupMessages(devtools::load_all("..", quiet = TRUE))

vignettes <- commandArgs(trailingOnly = TRUE)
if (!length(vignettes)) vignettes <- sub("\\.Rmd\\.orig$", "", list.files(pattern = "\\.Rmd\\.orig$"))

for (v in vignettes) {
  message("Knitting ", v)
  env <- new.env()
  knitr::knit(paste0(v, ".Rmd.orig"), paste0(v, ".Rmd"), envir = env, quiet = TRUE)
  leaks <- env$.anon_leaks()
  out <- enc2utf8(readLines(paste0(v, ".Rmd"), warn = FALSE, encoding = "UTF-8"))
  leaks <- enc2utf8(leaks)
  esc <- gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", leaks)
  hit <- leaks[vapply(esc, function(p) any(grepl(paste0("(^|[^0-9A-Za-z])", p, "($|[^0-9A-Za-z])"), out, useBytes = TRUE)), logical(1))]
  if (length(hit)) {
    for (h in hit) message("  leak on line(s) ",
      paste(grep(h, out, fixed = TRUE, useBytes = TRUE), collapse = ", "), " of ", v, ".Rmd")
    file.remove(paste0(v, ".Rmd"))
    stop(v, ": ", length(hit), " real rider ids or names appear in the output; removed it.", call. = FALSE)
  }
  message("  ", length(leaks), " real ids and names checked; none in the output.")
}
