# Is caching currently enabled?

Responses are cached as parsed JSON, keyed on method + URL + body, with
a per-call time-to-live (`ttl`: `0` = off, `Inf` = permanent, else
seconds). Entries live on disk in
[`zv_cache_dir()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_dir.md)
and, within an R session, in memory too, so repeated hits skip the disk
read. Options:

## Usage

``` r
zv_cache_enabled()
```

## Value

Logical scalar.

## Details

- `zwiftverse.cache` — master switch (default `TRUE`).

- `zwiftverse.cache_dir` — cache location (default
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)).

- `zwiftverse.cache_memory` — keep the in-session memory copy (default
  `TRUE`; set `FALSE` to bound memory when pulling many large payloads).

- `zwiftverse.ttl_zwift`, `zwiftverse.ttl_zp`, `zwiftverse.ttl_zr` —
  default TTLs (900, 3600, 3600 seconds).

## Examples

``` r
zv_cache_enabled()
#> [1] TRUE
old <- options(zwiftverse.cache = FALSE)   # turn caching off for a while
zv_cache_enabled()
#> [1] FALSE
options(old)
```
