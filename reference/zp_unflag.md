# Unwrap ZwiftPower `[value, flag]` columns

Many ZwiftPower numeric fields arrive as small arrays rather than
scalars, which become list-columns in the returned tibble:

## Usage

``` r
zp_unflag(tbl)
```

## Arguments

- tbl:

  A tibble returned by a `zp_*()` function.

## Value

`tbl` with those list-columns replaced by atomic columns.

## Details

- `[value, flag]` pairs — results/profile fields such as `avg_wkg`,
  `avg_power`, `time`, `weight`, `wkg1200`;

- `[code, value, percentile]` triples — the sign-up power bests
  (`cp_300_wkg`, `cp_1200_watts`, ...). Verified: element 2 is the value
  (`cp_*_watts[2] / weight == cp_*_wkg[2]`).

`zp_unflag()` replaces every such column with its value, converted to
number where possible.

## Examples

``` r
x <- tibble::tibble(zwid = 1:2,
                    avg_wkg = list(c("3.8", "0"), c("4.1", "0")),
                    cp_300_wkg = list(c("8", "3.7", "23.4"), c("8", "4.2", "51.0")))
zp_unflag(x)
#> # A tibble: 2 × 3
#>    zwid avg_wkg cp_300_wkg
#>   <int>   <dbl>      <dbl>
#> 1     1     3.8        3.7
#> 2     2     4.1        4.2
```
