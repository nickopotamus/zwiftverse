# Low-level ZwiftRacing.app GET

Low-level ZwiftRacing.app GET

## Usage

``` r
zr_get(client, path, query = list(), parse = "tbl", ttl = .zv_ttl("zr"))

zr_rider(client, zwift_id, ...)

zr_rider_overview(client, zwift_id, ...)

zr_rider_results(
  client,
  zwift_id,
  days = 365,
  parse = "tbl",
  ttl = .zv_ttl("zr")
)

zr_rider_ranking(client, zwift_id, days = 90, ...)

zr_rider_velo(client, zwift_id, days = 365, ...)

zr_rider_power(client, zwift_id, ...)

zr_riders(client, ids, ...)

zr_event(client, event_id, ...)

zr_result(client, event_id, parse = "tbl", ttl = .zv_ttl("zr"))

zr_club(client, club_id, ...)

zr_club_riders(client, club_id, page = NULL, ...)

zr_routes(client, ...)
```

## Arguments

- client:

  A
  [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md).

- path:

  Endpoint path under `/api/v2`, e.g. `"/riders/123"`.

- query:

  Named list of query parameters.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

- ttl:

  Cache time-to-live in seconds (`0` = off, `Inf` = permanent).

- zwift_id:

  Zwift rider id.

- ...:

  For the typed wrappers, further arguments forwarded to `zr_get()`.

- days:

  Look-back window in days.

- ids:

  Vector of Zwift rider ids.

- event_id:

  Zwift event id.

- club_id:

  Club id.

- page:

  Page number (0-based), or `NULL` for all pages.

## Value

A tibble, parsed list, or httr2 response.

## Functions

- `zr_rider()`: A rider's current profile: vELO rating (`velo$race`,
  with `velo$factors`), race counts (`race$finishes/wins/podiums/dnfs`),
  power, points, phenotype and club.

- `zr_rider_overview()`: Rider overview, including the legacy
  ZwiftRacing ratings (`legacyRatings$live/max30/max90`) and rating
  history.

- `zr_rider_results()`: A rider's race results over the last `days`
  days. One row per race (nested `event`, `place`, `race`, `velo`,
  `legacy` objects, flattened to dotted column names).

- `zr_rider_ranking()`: A rider's ranking / points over the last `days`
  days.

- `zr_rider_velo()`: A rider's vELO rating history over the last `days`
  days.

- `zr_rider_power()`: A rider's power curve, efforts and FTP estimate.

- `zr_riders()`: Several riders' profiles, one row each. API v2 has no
  batch endpoint, so this makes one (throttled, cached) request per
  rider; riders that error (e.g. not found / opted out) are dropped with
  a warning.

- `zr_event()`: Event metadata (route, distance, pens with summary
  stats).

- `zr_result()`: Race results for an event: one row per rider across all
  pens, with a `pen` column. Includes `position`, `category`, `time`,
  power (`wkg*`), and ratings (`ratingBefore`, `rating`, `ratingDelta`,
  `riderVelo.race`).

- `zr_club()`: Club summary (name, colours, rider counts).

- `zr_club_riders()`: Club members with ratings. Pages hold 50 riders
  and are 0-indexed; `page = NULL` (default) fetches every page and
  binds them.

- `zr_routes()`: Route catalogue.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()
zr_get(zr, "/riders/1234567")
zr_get(zr, "/riders/1234567", parse = "json", ttl = 0)  # raw list, no cache
} # }
```
