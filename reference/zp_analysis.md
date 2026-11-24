# Race-report data streams from ZwiftPower

The data behind ZwiftPower's race report (`racereport.php`): a rider's
second-by-second power, heart rate and altitude through one event, from
`api3.php?do=analysis`.

## Usage

``` r
zp_analysis(s, race_id, zwift_id, parse = "tbl", ttl = .zv_ttl("zp"))

zp_event_analysis(
  s,
  race_id,
  pen = NULL,
  zwift_ids = NULL,
  ...,
  progress = interactive()
)
```

## Arguments

- s:

  A
  [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md).

- race_id:

  ZwiftPower (= Zwift) event id.

- zwift_id:

  Zwift rider id.

- parse:

  `"tbl"` for the tidy stream tibble, or `"json"` / `"resp"` for the raw
  payload (`zp_analysis()` only).

- ttl:

  Cache time-to-live in seconds.

- pen:

  Optional pen (category) letter(s), e.g. `"B"`.

- zwift_ids:

  Optional rider ids to restrict to.

- ...:

  Passed to `zp_analysis()` (e.g. `ttl`).

- progress:

  Show a progress bar.

## Value

A tibble with one row per sample: `zwid`, `time` (seconds from the
rider's start), `distance` (km), then one column per stream ZwiftPower
holds for the rider — usually `power` (W), `heart_rate` (bpm) and
`altitude` (m); `cadence` (rpm) and `speed` (km/h) appear when present,
other streams are named after their unit. A rider with no data gives
zero rows. `zp_event_analysis()` adds `name` and `category` from the
results.

## Details

`zp_analysis()` fetches one rider. `zp_event_analysis()` fetches every
finisher in an event's results, optionally only one pen or a set of
riders, one request per rider (each cached, so re-runs are cheap).

## Examples

``` r
if (FALSE) { # \dontrun{
zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
winner <- zp_analysis(zp, 5811034, 1366959)
pen_b  <- zp_event_analysis(zp, 5811034, pen = "B")
} # }
```
