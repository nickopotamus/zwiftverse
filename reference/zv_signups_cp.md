# Critical power and W' for everyone signed up to a race

Runs
[`zv_rider_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_rider_cp.md)
for every rider on a race's ZwiftPower sign-up list, optionally one pen
only.

## Usage

``` r
zv_signups_cp(zr, zp, race_id, pen = NULL, ..., progress = interactive())
```

## Arguments

- zr:

  A
  [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md),
  or `NULL` to use only the ZwiftPower fit.

- zp:

  A
  [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md)
  (required: the sign-ups come from ZwiftPower).

- race_id:

  ZwiftPower (= Zwift) event id.

- pen:

  Optional pen letter(s), e.g. `"C"`.

- ...:

  Passed to
  [`zv_rider_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_rider_cp.md)
  (`max_age_days`, `durations`, `tries`).

- progress:

  Show a progress bar.

## Value

A tibble with one row per signed-up rider: `zwid`, `name`, `team`,
`pen`, `weight` (kg, from the sign-up), the columns of
[`zv_rider_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_rider_cp.md),
plus `cp_wkg` and `w_prime_jkg`.

## Details

Each rider can cost a ZwiftPower race-history request, up to `tries`
ZwiftRacing.app results requests and a ZwiftPower power-curve request.
All are cached. ZwiftRacing allows a user key at most one results
request a minute, so with `zr` a large field can take a long time the
first time; pass `zr = NULL` for a quick ZwiftPower-only table. If the
key has no results allowance at all, ZwiftRacing is dropped after the
first rider.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()
zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
field <- zv_signups_cp(zr, zp, 5812345, pen = "C")
dplyr::arrange(field, dplyr::desc(cp_wkg))
} # }
```
