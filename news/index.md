# Changelog

## zwiftverse (development version)

### Breaking changes

- ZwiftRacing.app keys now belong to user accounts (Hobby API Access).
  [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md)
  treats a key as a user key by default and sends it as `Authorization`
  to the public routes (`/api/public/...`). The old behaviour
  (`x-api-key` on the website’s v2 routes) needs `key_type = "service"`.
  [`zr_rider_results()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_rider_power()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_rider_velo()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_rider_overview()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_rider_ranking()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_event()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  and
  [`zr_routes()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  exist only on those v2 routes, and now stop with a
  `zv_zr_service_only` error under a user key.

- With a user key,
  [`zr_riders()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  is one batch POST per 1,000 riders, rather than one request per rider.
  [`zr_rider()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  and
  [`zr_riders()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  take `time =` for a snapshot, which rewinds the ZwiftRacing rating
  (vELO and power stay current).

- A route your ZwiftRacing tier has no allowance for (a 429 with
  `ratelimit-policy: 0`) fails at once with a `zv_zr_no_access` error
  rather than being retried. Long rate-limit waits are reported with the
  time to wait.

- Requests now identify as zwiftverse with a link to the repo, rather
  than as the Zwift mobile app.

- The package is now read-only: `zwift_give_rideon()` and the low-level
  `zwift_post()` have been removed.
  [`zwift_rideons()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  (reading the Ride Ons on an activity) stays.

### New features

- [`zv_rider_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_rider_cp.md)
  returns a rider’s latest critical power and W’. It reads
  ZwiftRacing.app’s modelled values (`power.CP`, `power.AWC`) from their
  most recent race result within 90 days. Failing that, it fits the
  two-parameter CP model to their ZwiftPower 90-day power curve.
  [`zv_signups_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_signups_cp.md)
  does the same for everyone signed up to a race, optionally one pen.
- [`zr_zp_result()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md),
  [`zr_categories()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  and
  [`zr_route_weights()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  cover the remaining public ZwiftRacing.app routes.
- [`zp_power_curve()`](https://nickopotamus.github.io/zwiftverse/reference/zp_power_curve.md):
  a rider’s best-power curve from ZwiftPower (90-day, 30-day or a single
  event).
- [`zwift_status()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_status.md)
  reads Zwift’s public status page: overall status, per-service
  components, open and recent incidents, upcoming maintenance. No login
  needed.
- [`zp_analysis()`](https://nickopotamus.github.io/zwiftverse/reference/zp_analysis.md)
  and
  [`zp_event_analysis()`](https://nickopotamus.github.io/zwiftverse/reference/zp_analysis.md)
  return the second-by-second power, heart rate and altitude behind
  ZwiftPower race reports, for one rider or a whole event / pen.
- [`zp_segment_standings()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md):
  every best effort on a ZwiftPower segment, globally or for one team.
- Cached responses are also kept in memory for the R session, so repeat
  hits skip the disk read (`options(zwiftverse.cache_memory = FALSE)` to
  turn off).
- [`print()`](https://rdrr.io/r/base/print.html) on a
  [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  handle shows token status without revealing the token or credentials.

### Bug fixes

- ZwiftPower text now decodes accented-letter entities, so names such as
  “Müller” come back as “Müller”. All the Latin-1 letters and a few
  Latin Extended-A ones are covered, and unknown entity names are left
  as they are.

### Documentation

- README explains where each credential comes from, including how to ask
  ZwiftRacing.app for an API key, and acknowledges zpdatafetch and
  zwift-api-documentation.

### Robustness

- [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  renews tokens early and times their expiry from when the request was
  sent, falls back to a password login when Zwift rejects a refresh
  token, treats `refresh_expires_in = 0` as non-expiring, and
  [`zwift_get()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  retries once with a fresh token after an unexpected 401.
- Error responses with an empty body now report their HTTP status
  instead of a body-parsing error.
- An empty response body (ZwiftPower’s “no data”) parses as an empty
  result.

## zwiftverse 0.1.0

- First version: typed clients for the Zwift game API, ZwiftPower and
  the ZwiftRacing.app v2 API, returning tibbles; auto-paging Zwift lists
  and event results / entrants;
  [`zp_unflag()`](https://nickopotamus.github.io/zwiftverse/reference/zp_unflag.md)
  for ZwiftPower’s `[value, flag]` fields; an on-disk TTL cache; offline
  fixture tests; vignettes `race-analysis` and `climb-prediction`.
