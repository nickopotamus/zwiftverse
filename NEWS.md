# zwiftverse (development version)

## Breaking changes

* ZwiftRacing.app service keys (`zr_client(key_type = "service")`) are
  deprecated: keys issued before ZwiftRacing.app accounts existed stop working
  on 1 January 2027. A service client warns once per session.
  `zr_rider_results()`, `zr_rider_power()`, `zr_rider_velo()`,
  `zr_rider_overview()`, `zr_rider_ranking()`, `zr_event()` and `zr_routes()`
  need one and will be removed after that date.

* ZwiftRacing.app keys now belong to user accounts (Hobby API Access).
  `zr_client()` treats a key as a user key by default and sends it as
  `Authorization` to the public routes (`/api/public/...`). The old behaviour
  (`x-api-key` on the website's v2 routes) needs `key_type = "service"`.
  `zr_rider_results()`, `zr_rider_power()`, `zr_rider_velo()`,
  `zr_rider_overview()`, `zr_rider_ranking()`, `zr_event()` and `zr_routes()`
  exist only on those v2 routes, and now stop with a `zv_zr_service_only`
  error under a user key.
* With a user key, `zr_riders()` is one batch POST per 1,000 riders, rather
  than one request per rider. `zr_rider()` and `zr_riders()` take `time =`
  for a snapshot, which rewinds the ZwiftRacing rating (vELO and power stay
  current).
* A route your ZwiftRacing tier has no allowance for (a 429 with
  `ratelimit-policy: 0`) fails at once with a `zv_zr_no_access` error rather
  than being retried. Long rate-limit waits are reported with the time to
  wait.

* Requests now identify as zwiftverse with a link to the repo, rather than as
  the Zwift mobile app.
* The package is now read-only: `zwift_give_rideon()` and the low-level
  `zwift_post()` have been removed. `zwift_rideons()` (reading the Ride Ons on
  an activity) stays.

## New features

* `zv_rider_cp()` returns a rider's latest critical power and W'. It reads
  ZwiftRacing.app's modelled values (`power.CP`, `power.AWC`) from their most
  recent race result within 90 days. Failing that, it fits the two-parameter
  CP model to their ZwiftPower 90-day power curve. `zv_signups_cp()` does the
  same for everyone signed up to a race, optionally one pen.
* `zr_zp_result()`, `zr_categories()` and `zr_route_weights()` cover the
  remaining public ZwiftRacing.app routes.
* `zp_power_curve()`: a rider's best-power curve from ZwiftPower (90-day,
  30-day or a single event).
* `zwift_status()` reads Zwift's public status page: overall status,
  per-service components, open and recent incidents, upcoming maintenance.
  No login needed.
* `zp_analysis()` and `zp_event_analysis()` return the second-by-second
  power, heart rate and altitude behind ZwiftPower race reports, for one rider
  or a whole event / pen.
* `zp_segment_standings()`: every best effort on a ZwiftPower segment,
  globally or for one team.
* Cached responses are also kept in memory for the R session, so repeat hits
  skip the disk read (`options(zwiftverse.cache_memory = FALSE)` to turn off).
* `print()` on a `zwift_auth()` handle shows token status without revealing
  the token or credentials.


## Bug fixes

* `zr_club_riders()` with an account key started each page at the last rider
  of the previous one, repeating that rider. The start id is inclusive, so
  pages now start at the last id plus one (per zwiftracing.app/developer).
* ZwiftRacing.app's daily cap (250 rider GETs and 15 POSTs per UTC day) now
  fails at once with a `zv_zr_daily_limit` error saying when it resets, rather
  than a misleading "try again in 3600 s" or retries. Rate limits are read
  from the 429 body when the headers don't carry them.
* The `zv_zr_no_access` error now says when a route is for event organisers
  only (results, ZwiftPower results, categories, route factor weights), rather
  than suggesting a tier problem.

* ZwiftPower text now decodes accented-letter entities, so names such as
  "M&uuml;ller" come back as "Müller". All the Latin-1 letters and a few
  Latin Extended-A ones are covered, and unknown entity names are left as
  they are.

## Documentation

* The two vignettes are now pre-rendered from live data, so the website shows
  real output and figures. `vignettes/precompute.R` knits each
  `vignettes/*.Rmd.orig` into the `.Rmd` that is shipped; riders are
  pseudonymised while knitting (names, rider ids and team names), and the run
  fails if any real id or name reaches the output.

* README explains where each credential comes from, including how to ask
  ZwiftRacing.app for an API key, and acknowledges zpdatafetch and
  zwift-api-documentation.

## Robustness

* `zwift_auth()` renews tokens early and times their expiry from when the
  request was sent, falls back to a password login when Zwift rejects a
  refresh token, treats `refresh_expires_in = 0` as non-expiring, and
  `zwift_get()` retries once with a fresh token after an
  unexpected 401.
* Error responses with an empty body now report their HTTP status instead of
  a body-parsing error.
* An empty response body (ZwiftPower's "no data") parses as an empty result.

# zwiftverse 0.1.0

* First version: typed clients for the Zwift game API, ZwiftPower and the
  ZwiftRacing.app v2 API, returning tibbles; auto-paging Zwift lists and
  event results / entrants; `zp_unflag()` for ZwiftPower's `[value, flag]`
  fields; an on-disk TTL cache; offline fixture tests; vignettes
  `race-analysis` and `climb-prediction`.
