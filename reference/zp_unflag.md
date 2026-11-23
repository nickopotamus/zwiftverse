# Unwrap ZwiftPower `[value, flag]` columns

Many ZwiftPower numeric fields (`avg_wkg`, `avg_power`, `time`,
`weight`, `wkg1200`, ...) arrive as two-element `[value, flag]` arrays,
which become list-columns in the returned tibble. `zp_unflag()` replaces
every such column with its first element, converted to number where
possible. The flag (an upload/verification marker) is dropped.

## Usage

``` r
zp_unflag(tbl)
```

## Arguments

- tbl:

  A tibble returned by a `zp_*()` function.

## Value

`tbl` with `[value, flag]` list-columns replaced by atomic columns.

## Examples

``` r
x <- tibble::tibble(zwid = 1:2, avg_wkg = list(c("3.8", "0"), c("4.1", "0")))
zp_unflag(x)
#> # A tibble: 2 × 2
#>    zwid avg_wkg
#>   <int>   <dbl>
#> 1     1     3.8
#> 2     2     4.1
```
