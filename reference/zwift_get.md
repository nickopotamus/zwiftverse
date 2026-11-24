# Low-level Zwift GET

Low-level Zwift GET

## Usage

``` r
zwift_get(auth, path, query = list(), parse = "tbl", ttl = .zv_ttl("zwift"))

zwift_profile(auth, rider_id = "me", ...)

zwift_activities(
  auth,
  rider_id = "me",
  start = 0,
  limit = 20,
  parse = "tbl",
  ttl = .zv_ttl("zwift")
)

zwift_activity(auth, activity_id, ...)

zwift_followers(
  auth,
  rider_id = "me",
  start = 0,
  limit = Inf,
  parse = "tbl",
  ttl = .zv_ttl("zwift")
)

zwift_followees(
  auth,
  rider_id = "me",
  start = 0,
  limit = Inf,
  parse = "tbl",
  ttl = .zv_ttl("zwift")
)

zwift_rideons(auth, rider_id, activity_id, ...)

zwift_event(auth, event_id, ...)

zwift_event_subgroups(auth, event_id, parse = "tbl", ttl = .zv_ttl("zwift"))

zwift_subgroup_results(
  auth,
  subgroup_id,
  start = 0,
  limit = Inf,
  parse = "tbl",
  ttl = .zv_ttl("zwift")
)

zwift_event_results(auth, event_id, ttl = .zv_ttl("zwift"))

zwift_subgroup_entrants(
  auth,
  subgroup_id,
  participation = "signed_up",
  start = 0,
  limit = Inf,
  parse = "tbl",
  ttl = .zv_ttl("zwift")
)

zwift_event_entrants(
  auth,
  event_id,
  participation = "signed_up",
  ttl = .zv_ttl("zwift")
)

zwift_worlds(auth, ...)

zwift_riders_in_world(auth, world_id = 1, ...)
```

## Arguments

- auth:

  A
  [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  handle.

- path:

  Endpoint path, e.g. `"/api/profiles/me"`.

- query:

  Named list of query parameters.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

- ttl:

  Cache time-to-live in seconds (`0` = off, `Inf` = permanent).

- rider_id:

  Zwift rider id, or `"me"`.

- ...:

  For the typed wrappers, further arguments forwarded to `zwift_get()`
  (e.g. `parse`, `ttl`).

- start, limit:

  Offset of the first record, and how many records to return (`Inf` =
  all). Paging happens automatically.

- activity_id:

  Zwift activity id.

- event_id:

  Zwift event id.

- subgroup_id:

  Event subgroup id (from `zwift_event_subgroups()`).

- participation:

  Entrant filter passed to the API; `"signed_up"` is the value verified
  to work.

- world_id:

  World id (1 = Watopia host world).

## Value

A tibble, parsed list, or httr2 response.

## Functions

- `zwift_profile()`: A rider's profile (`"me"` or a Zwift id).

- `zwift_activities()`: A rider's activities, newest first. `limit` is
  the total wanted: values above the server's page size (50) are fetched
  page by page and bound; `limit = Inf` fetches the whole history.

- `zwift_activity()`: A single activity by id.

- `zwift_followers()`: A rider's followers (auto-paged, 200 per
  request).

- `zwift_followees()`: Riders a rider follows (auto-paged, 200 per
  request).

- `zwift_rideons()`: Ride Ons on an activity.

- `zwift_event()`: An event by id.

- `zwift_event_subgroups()`: An event's subgroups (pens / categories):
  one row each, with `id` (the subgroup id used by the results and
  entrants functions), `subgroupLabel` (A, B, ...), start time and
  route.

- `zwift_subgroup_results()`: Official Zwift race results for one
  subgroup, in finishing order (`rank`), auto-paged (50 per request).
  Nested objects are flattened: `activityData.*`, `criticalP.*`,
  `sensorData.*`, `profileData.*`, `scoreHistory.*`.

- `zwift_event_results()`: Race results for every subgroup of an event,
  bound into one tibble with a leading `subgroup` label column.

- `zwift_subgroup_entrants()`: Riders signed up to one subgroup
  (auto-paged).

- `zwift_event_entrants()`: Sign-ups for every subgroup of an event,
  with a leading `subgroup` label column.

- `zwift_worlds()`: List of active worlds.

- `zwift_riders_in_world()`: Roster of riders currently in a world. Live
  position/power is protobuf on `/relay/worlds/{id}/players/{id}`; this
  JSON endpoint returns the roster only.

## Examples

``` r
if (FALSE) { # \dontrun{
za <- zwift_auth()
zwift_get(za, "/api/profiles/me/activities/", list(limit = 5))
zwift_get(za, "/api/profiles/me", parse = "json")
} # }
```
