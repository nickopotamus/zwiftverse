# Summarise the cache contents.

Summarise the cache contents.

## Usage

``` r
zv_cache_info()
```

## Value

A tibble: one row per cached entry (key, bytes, modified).

## Examples

``` r
info <- zv_cache_info()
nrow(info)          # number of cached responses
#> [1] 0
sum(info$bytes)     # disk used
#> [1] 0
```
