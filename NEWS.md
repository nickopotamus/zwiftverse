# zwiftverse (development version)

## Breaking changes

* Requests now identify as zwiftverse with a link to the repo, rather than as
  the Zwift mobile app.
* The package is now read-only: `zwift_give_rideon()` and the low-level
  `zwift_post()` have been removed. `zwift_rideons()` (reading the Ride Ons on
  an activity) stays.

## New features

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

## Documentation

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
