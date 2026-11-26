# A rider's power curve from ZwiftPower

The best-power curve behind a ZwiftPower profile page
(`api3.php?do= critical_power_profile`): best average watts for
durations from 1 s to about an hour, over a rolling window, with the
date and event of each best.

## Usage

``` r
zp_power_curve(
  s,
  zwift_id,
  window = "90days",
  parse = "tbl",
  ttl = .zv_ttl("zp")
)
```

## Arguments

- s:

  A
  [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md).

- zwift_id:

  Zwift rider id.

- window:

  `"90days"` (default), `"30days"`, or an event id for that event's
  curve.

- parse:

  `"tbl"`, `"json"` or `"resp"`.

- ttl:

  Cache time-to-live in seconds.

## Value

A tibble with one row per duration: `secs`, `watts`, `date` (POSIXct of
the effort) and `event_id`. Zero rows when ZwiftPower holds no curve for
the rider or window.

## Examples

``` r
if (FALSE) { # \dontrun{
zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
zp_power_curve(zp, 1234567)
zp_power_curve(zp, 1234567, window = "30days")
} # }
```
