# Shared endpoint catalogue for dev/smoke-live.R and dev/capture-fixtures.R.
# Not part of the package (dev/ is .Rbuildignore'd).
#
# Credentials (put these in ~/.Renviron or a project .Renviron - both gitignored;
# never commit them):
#   ZR_AUTH            ZwiftRacing.app key (sent as the x-api-key header)
#   ZWIFT_USERNAME     Zwift login
#   ZWIFT_PASSWORD     Zwift password
#   ZP_SID             phpbb3_lswlk_sid cookie copied from zwiftpower.com
#
# Test targets - put these in dev/local.env (gitignored, KEY=value lines; read
# automatically below) or in ~/.Renviron. Any you leave unset are skipped:
#   ZV_RIDER_ID        a Zwift rider id (yours is fine). If unset and Zwift
#                      creds work, taken from zwift_profile("me").
#   ZV_RIDER_IDS       extra comma-separated rider ids for zr_riders()
#   ZV_ZP_RACE_ID      a *completed* ZwiftPower event id
#   ZV_ZP_TEAM_ID      a ZwiftPower team id
#   ZV_ZR_RACE_ID      a ZwiftRacing.app event id (often same as the ZP/Zwift id)
#   ZV_ZR_CLUB_ID      a ZwiftRacing.app club id
#   ZV_ZWIFT_EVENT_ID  a Zwift event id
#   ZV_ZP_SEGMENT_ID   a ZwiftPower segment id (default 13, Watopia Epic KOM)

if (file.exists("dev/local.env")) readRenviron("dev/local.env")

suppressPackageStartupMessages({
  if (requireNamespace("devtools", quietly = TRUE) && file.exists("DESCRIPTION")) {
    devtools::load_all(".", quiet = TRUE)
  } else {
    library(zwiftverse)
  }
})

.env <- function(x) { v <- Sys.getenv(x); if (nzchar(v)) v else NULL }
.ids <- function(x) { v <- .env(x); if (is.null(v)) NULL else trimws(strsplit(v, ",")[[1]]) }

# Build the list of endpoint specs given whichever credentials exist.
# Each spec: api, name, needs (env vars that must be set), call(handles) -> httr2 resp.
zv_dev_specs <- function() {
  rider <- function(h) h$rider_id
  list(
    # ---- ZwiftRacing.app (v2) ----
    list(api = "zr", name = "rider",          needs = "rider",
         call = function(h) zr_rider(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "rider_overview", needs = "rider",
         call = function(h) zr_rider_overview(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "rider_results",  needs = "rider",
         call = function(h) zr_rider_results(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "rider_ranking",  needs = "rider",
         call = function(h) zr_rider_ranking(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "rider_velo",     needs = "rider",
         call = function(h) zr_rider_velo(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "rider_power",    needs = "rider",
         call = function(h) zr_rider_power(h$zr, rider(h), parse = "resp")),
    list(api = "zr", name = "event",          needs = "ZV_ZR_RACE_ID",
         call = function(h) zr_event(h$zr, .env("ZV_ZR_RACE_ID"), parse = "resp")),
    list(api = "zr", name = "club",           needs = "ZV_ZR_CLUB_ID",
         call = function(h) zr_club(h$zr, .env("ZV_ZR_CLUB_ID"), parse = "resp")),
    list(api = "zr", name = "club_riders",    needs = "ZV_ZR_CLUB_ID",
         call = function(h) zr_club_riders(h$zr, .env("ZV_ZR_CLUB_ID"), page = 0, parse = "resp")),
    list(api = "zr", name = "routes",         needs = character(),
         call = function(h) zr_routes(h$zr, parse = "resp")),
    # ---- Zwift game API ----
    list(api = "zwift", name = "profile",    needs = character(),
         call = function(h) zwift_profile(h$zwift, "me", parse = "resp")),
    list(api = "zwift", name = "activities", needs = character(),
         call = function(h) zwift_activities(h$zwift, "me", limit = 3, parse = "resp")),
    list(api = "zwift", name = "followees",  needs = character(),
         call = function(h) zwift_followees(h$zwift, "me", limit = 5, parse = "resp")),
    list(api = "zwift", name = "event",      needs = "ZV_ZWIFT_EVENT_ID",
         call = function(h) zwift_event(h$zwift, .env("ZV_ZWIFT_EVENT_ID"), parse = "resp")),
    list(api = "zwift", name = "subgroup_results", needs = "ZV_ZP_RACE_ID",
         call = function(h) zwift_subgroup_results(h$zwift, .zv_dev_sgid(h), limit = 50, parse = "resp")),
    list(api = "zwift", name = "subgroup_entrants", needs = "ZV_ZP_RACE_ID",
         call = function(h) zwift_subgroup_entrants(h$zwift, .zv_dev_sgid(h), limit = 50, parse = "resp")),
    list(api = "zwift", name = "worlds",     needs = character(),
         call = function(h) zwift_worlds(h$zwift, parse = "resp")),
    # ---- ZwiftPower ----
    list(api = "zp", name = "profile",  needs = "rider",
         call = function(h) zp_profile(h$zp, rider(h), parse = "resp")),
    list(api = "zp", name = "result",   needs = "ZV_ZP_RACE_ID",
         call = function(h) zp_result(h$zp, .env("ZV_ZP_RACE_ID"), parse = "resp")),
    list(api = "zp", name = "signups",  needs = "ZV_ZP_RACE_ID",
         call = function(h) zp_signups(h$zp, .env("ZV_ZP_RACE_ID"), parse = "resp")),
    list(api = "zp", name = "sprints",  needs = "ZV_ZP_RACE_ID",
         call = function(h) zp_sprints(h$zp, .env("ZV_ZP_RACE_ID"), parse = "resp")),
    list(api = "zp", name = "primes",   needs = "ZV_ZP_RACE_ID",
         call = function(h) zp_primes(h$zp, .env("ZV_ZP_RACE_ID"), parse = "resp")),
    list(api = "zp", name = "segment_standings", needs = "ZV_ZP_TEAM_ID",
         call = function(h) zp_segment_standings(h$zp, .env("ZV_ZP_SEGMENT_ID") %||% 13,
                                                 .env("ZV_ZP_TEAM_ID"), parse = "resp")),
    list(api = "zp", name = "analysis", needs = "ZV_ZP_RACE_ID",
         call = function(h) zp_analysis(h$zp, .env("ZV_ZP_RACE_ID"),
                                        zp_result(h$zp, .env("ZV_ZP_RACE_ID"))$zwid[[1]],
                                        parse = "resp")),
    list(api = "zp", name = "team",     needs = "ZV_ZP_TEAM_ID",
         call = function(h) zp_team(h$zp, .env("ZV_ZP_TEAM_ID"), parse = "resp"))
  )
}

# Create whichever API handles we have credentials for. Never prints secrets.
zv_dev_handles <- function() {
  h <- list()
  if (!is.null(.env("ZR_AUTH"))) h$zr <- zr_client()
  if (!is.null(.env("ZWIFT_USERNAME")) && !is.null(.env("ZWIFT_PASSWORD"))) {
    h$zwift <- tryCatch({ a <- zwift_auth(); a$token(); a },
                        error = function(e) { message("Zwift auth FAILED: ", conditionMessage(e)); NULL })
    if (!is.null(h$zwift)) message("Zwift auth OK via ", h$zwift$.state$auth_url)
  }
  if (!is.null(.env("ZP_SID"))) h$zp <- zp_set_cookie(zp_session(), .env("ZP_SID"))
  h$rider_id <- .env("ZV_RIDER_ID")
  if (is.null(h$rider_id) && !is.null(h$zwift)) {
    h$rider_id <- tryCatch(as.character(zwift_profile(h$zwift, parse = "json", ttl = 0)$id),
                           error = function(e) NULL)
  }
  h
}

# First subgroup of the ZwiftPower race (Zwift and ZP share event ids).
.zv_dev_sgid <- function(h)
  zwift_event_subgroups(h$zwift, .env("ZV_ZP_RACE_ID"), ttl = 0)$id[[1]]

zv_dev_runnable <- function(spec, h) {
  if (is.null(h[[spec$api]])) return(paste("no", spec$api, "credentials"))
  for (n in spec$needs) {
    if (n == "rider") { if (is.null(h$rider_id)) return("ZV_RIDER_ID unset") }
    else if (is.null(.env(n))) return(paste(n, "unset"))
  }
  NULL
}
