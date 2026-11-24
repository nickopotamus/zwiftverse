# Record PII-scrubbed JSON fixtures for the offline parsing tests.
#   Rscript dev/capture-fixtures.R            (from the package root)
#   Rscript dev/capture-fixtures.R zp/analysis   (only the named fixture(s))
# Uses the same credentials / ids as dev/smoke-live.R. Writes one file per
# endpoint to tests/testthat/fixtures/<api>/<endpoint>.json. Real rider ids,
# names, emails etc. are replaced (see dev/scrub.R) - but ALWAYS eyeball the
# diff before committing:  grep -rn "<your name>" tests/testthat/fixtures

source("dev/endpoints.R")
source("dev/scrub.R")
options(zwiftverse.cache = FALSE)

h <- zv_dev_handles()
m <- zv_scrub_new_map()
zv_scrub_seed(m, c(h$rider_id, .ids("ZV_RIDER_IDS")))

only <- commandArgs(trailingOnly = TRUE)

n <- 0
for (s in zv_dev_specs()) {
  if (length(only) && !paste0(s$api, "/", s$name) %in% only) next
  why <- zv_dev_runnable(s, h)
  if (!is.null(why)) { message(sprintf("skip %s/%s (%s)", s$api, s$name, why)); next }
  ok <- tryCatch({
    txt <- httr2::resp_body_string(s$call(h))
    dir <- file.path("tests/testthat/fixtures", s$api)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    out <- file.path(dir, paste0(s$name, ".json"))
    writeLines(zv_scrub_json(txt, m), out)
    message(sprintf("wrote %s (%s bytes)", out, format(file.size(out), big.mark = ",")))
    TRUE
  }, error = function(e) { message(sprintf("FAIL %s/%s: %s", s$api, s$name, conditionMessage(e))); FALSE })
  n <- n + ok
}

# Record which synthetic ids the tests should use (no real ids are written).
# Skipped for a partial capture, so ids.json keeps matching the other fixtures.
if (length(only)) quit(save = "no")
fake_rider <- if (!is.null(h$rider_id)) m$map[[as.character(h$rider_id)]] else NA
writeLines(jsonlite::toJSON(list(rider_id = fake_rider), auto_unbox = TRUE, pretty = TRUE),
           "tests/testthat/fixtures/ids.json")
message(sprintf("\n%d fixtures written. %d ids pseudonymised. Now run devtools::test().",
                n, length(m$map)))
