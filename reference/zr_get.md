# Low-level ZwiftRacing.app request

`zr_get()` sends a GET to any ZwiftRacing.app route. `path` is relative
to the host (`https://api.zwiftracing.app`), e.g.
`"/api/public/riders/123"` or, with a service key,
`"/api/v2/riders/123"`. For a `"service"` client, a path without a
leading `/api/` is taken as relative to `/api/v2`, as in earlier
versions.

## Usage

``` r
zr_get(client, path, query = list(), parse = "tbl", ttl = .zv_ttl("zr"))

zr_rider(client, zwift_id, time = NULL, ...)

zr_riders(client, ids, time = NULL, ...)

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

zr_event(client, event_id, ...)

zr_result(client, event_id, parse = "tbl", ttl = .zv_ttl("zr"))

zr_zp_result(client, event_id, parse = "tbl", ttl = .zv_ttl("zr"))

zr_club(client, club_id, ...)

zr_club_riders(client, club_id, page = NULL, ...)

zr_categories(client, ...)

zr_route_weights(
  client,
  route_id,
  laps = NULL,
  distance = NULL,
  event_type = c("race", "timeTrial"),
  ...
)

zr_routes(client, ...)
```

## Arguments

- client:

  A
  [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md).

- path:

  Route path (see Details).

- query:

  Named list of query parameters.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

- ttl:

  Cache time-to-live in seconds (`0` = off, `Inf` = permanent).

- zwift_id:

  Zwift rider id.

- time:

  Optional point in time for a historical snapshot.

- ...:

  For the typed wrappers, further arguments forwarded to `zr_get()`.

- ids:

  Vector of Zwift rider ids.

- days:

  Look-back window in days.

- event_id:

  Zwift event id.

- club_id:

  Club id.

- page:

  Page number (service key) or rider id to start after (user key), or
  `NULL` for every page.

- route_id:

  Zwift route id.

- laps, distance:

  Laps, or distance in metres (exactly one).

- event_type:

  `"race"` (default) or `"timeTrial"`.

## Value

A tibble, parsed list, or httr2 response.

## Details

**What each key reaches.** A user key (the default; Hobby API Access)
can call `zr_rider()`, `zr_riders()`, `zr_club()`, `zr_club_riders()`,
`zr_result()`, `zr_zp_result()`, `zr_categories()` and
`zr_route_weights()`, subject to its tier's per-route limits (some may
be 0). The rest (`zr_rider_overview()`, `zr_rider_results()`,
`zr_rider_ranking()`, `zr_rider_velo()`, `zr_rider_power()`,
`zr_event()`, `zr_routes()`) exist only on the website's v2 routes and
need a service key.

**Errors.** A route your tier has no allowance for fails at once with
class `zv_zr_no_access`; a service-only function called with a user key
fails with class `zv_zr_service_only`. Short rate-limit waits are
retried; long ones are reported with the time to wait.

## Functions

- `zr_rider()`: A rider's profile: vELO rating (`velo$race`, with
  `velo$factors`, `velo$category`), race counts, power bests (`power$w5`
  ... `power$w1200`, and w/kg), zFTP, phenotype and club. With `time`
  (POSIXct or Unix seconds; user keys only), a snapshot at that moment.
  Only the legacy ZwiftRacing rating (`race$current`) is rewound: vELO,
  power bests and race counts are always current (checked live,
  2026-11).

- `zr_riders()`: Several riders' profiles, one row each. With a user key
  this is one POST per 1000 riders (`time` gives snapshots, as for
  `zr_rider()`); with a service key, one request per rider. Riders that
  are unknown or opted out are simply absent.

- `zr_rider_overview()`: Rider overview, including the legacy
  ZwiftRacing ratings (`legacyRatings$live/max30/max90`) and rating
  history. Service key only.

- `zr_rider_results()`: A rider's race results over the last `days` days
  (90 or 365). One row per race (nested `event`, `place`, `race`,
  `velo`, `legacy` objects, flattened to dotted column names). Service
  key only.

- `zr_rider_ranking()`: A rider's ranking / points over the last `days`
  days. Service key only.

- `zr_rider_velo()`: A rider's vELO rating history over the last `days`
  days. Service key only.

- `zr_rider_power()`: A rider's power curve, efforts and FTP estimate.
  Service key only (a user key's `zr_rider()` carries the 5 s - 20 min
  bests).

- `zr_event()`: Event metadata (route, distance, pens with summary
  stats). Service key only.

- `zr_result()`: Race results for an event, one row per rider. With a
  service key this flattens the v2 event's pens and adds a `pen` column
  (`position`, `category`, `time`, `wkg*`, ratings, `power.CP`,
  `power.AWC`, ...). With a user key it reads `/api/public/results/:id`
  and returns its records as they come.

- `zr_zp_result()`: ZwiftPower's view of an event's results, as served
  by ZwiftRacing.app (`/api/public/zp/:id/results`). User key.

- `zr_club()`: Club summary. With a user key this is
  `/api/public/clubs/:id`, which also carries the first page of riders.

- `zr_club_riders()`: Club members with ratings. Service keys page by
  number (50 riders a page, 0-indexed; `page = NULL` fetches all). User
  keys page by rider id (`/api/public/clubs/:id/:riderId` returns riders
  with a higher id); `page = NULL` follows those pages to the end,
  otherwise `page` is the rider id to start after (`0` for the first
  page).

- `zr_categories()`: The vELO category bands (number, name, min, max) on
  the 1-1000 scale. User key.

- `zr_route_weights()`: How much each ability (endurance, pursuit,
  sprint, punch, climb, time trial) counts on a route, for a number of
  `laps` or a `distance` in metres (give one). User key.

- `zr_routes()`: Route catalogue. Service key only.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()
zr_get(zr, "/api/public/riders/1234567")
zr_rider(zr, 1234567)
zr_riders(zr, c(1234567, 2345678))        # one POST for up to 1000 riders
} # }
```
