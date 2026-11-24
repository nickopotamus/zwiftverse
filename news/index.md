# Changelog

## zwiftverse (development version)

### New features

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

### Robustness

- [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  renews tokens early and times their expiry from when the request was
  sent, falls back to a password login when Zwift rejects a refresh
  token, treats `refresh_expires_in = 0` as non-expiring, and
  [`zwift_get()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  /
  [`zwift_post()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_post.md)
  retry once with a fresh token after an unexpected 401.
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
