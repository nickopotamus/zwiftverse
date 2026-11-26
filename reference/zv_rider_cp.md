# A rider's critical power and W'

Looks up a rider's most recent critical power (CP, W) and W' (J) as
modelled by ZwiftRacing.app, or estimates them from ZwiftPower's 90-day
power curve when ZwiftRacing has nothing recent enough.

## Usage

``` r
zv_rider_cp(
  zr,
  zp,
  zwift_id,
  max_age_days = 90,
  durations = c(120, 1200),
  tries = 3
)
```

## Arguments

- zr:

  A
  [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md),
  or `NULL` to skip ZwiftRacing.app.

- zp:

  A
  [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md),
  or `NULL` to skip the ZwiftPower fallback.

- zwift_id:

  Zwift rider id.

- max_age_days:

  ZwiftRacing values older than this are ignored. At most 365.

- durations:

  Range of durations (seconds) used for the ZwiftPower fit.

- tries:

  How many of the rider's most recent ZwiftRacing events to try.

## Value

A one-row tibble: `zwid`, `cp` (W), `w_prime` (J), `source`
(`"zwiftracing"`, `"zwiftpower_fit"`, or `NA` if neither worked),
`as_of` (POSIXct: the event, or the newest effort in the fit),
`age_days`, `event_id` (the ZwiftRacing event the values come from) and
`fit_r2` (R² of the ZwiftPower fit; `NA` for ZwiftRacing values).

## Details

**ZwiftRacing.app.** CP and W' are only published inside event results,
as each rider's `power.CP` and `power.AWC` at the time of the event. The
function finds the rider's races from the last `max_age_days` and reads
their row from the newest event that has them (trying up to `tries`
events). A service key lists those races from ZwiftRacing; a user
(Hobby) key has no such route, so they come from the rider's ZwiftPower
race history, and `zp` is needed for this step too. If the key has no
allowance for event results, the function warns (now and then, not for
every rider) and uses the ZwiftPower fit.

**ZwiftPower fallback.** If ZwiftRacing has no result within
`max_age_days`, or `zr` is `NULL`, the two-parameter model
`P(t) = CP + W'/t` is fitted to the 90-day curve from
[`zp_power_curve()`](https://nickopotamus.github.io/zwiftverse/reference/zp_power_curve.md)
by linear regression of work on time (`P*t = W' + CP*t`) over the
`durations` range (default 2-20 minutes). The fit is only as good as the
efforts behind the curve: a rider who has not gone full gas for 2 and 20
minutes lately will get a low CP and an unreliable W'.

A rider or event the API doesn't know (HTTP 404) just moves on to the
next source. Any other error, such as a rejected key, is raised.

## See also

[`zv_signups_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_signups_cp.md)
for every rider signed up to a race.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()
zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
zv_rider_cp(zr, zp, 1234567)
zv_rider_cp(NULL, zp, 1234567)        # ZwiftPower fit only
} # }
```
