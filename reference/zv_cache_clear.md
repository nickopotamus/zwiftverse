# Clear the cache.

Removes every entry on disk and the in-session memory copy (see the
`zwiftverse.cache_memory` option in
[`zv_cache_enabled()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_enabled.md)).

## Usage

``` r
zv_cache_clear()
```

## Value

Invisibly, the number of cache files removed.
