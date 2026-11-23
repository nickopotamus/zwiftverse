# Low-level Zwift GET

Low-level Zwift GET

## Usage

``` r
zwift_get(auth, path, query = list(), parse = "tbl", ttl = .zv_ttl("zwift"))

zwift_profile(auth, rider_id = "me", ...)

zwift_activities(auth, rider_id = "me", start = 0, limit = 20, ...)

zwift_activity(auth, activity_id, ...)

zwift_followers(auth, rider_id = "me", start = 0, limit = 200, ...)

zwift_followees(auth, rider_id = "me", start = 0, limit = 200, ...)

zwift_rideons(auth, rider_id, activity_id, ...)

zwift_give_rideon(auth, rider_id, activity_id)

zwift_event(auth, event_id, ...)

zwift_worlds(auth, ...)

zwift_riders_in_world(auth, world_id = 1, ...)
```

## Arguments

- auth:

  A [`zwift_auth()`](zwift_auth.md) handle.

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

  Paging offset and page size.

- activity_id:

  Zwift activity id.

- event_id:

  Zwift event id.

- world_id:

  World id (1 = Watopia host world).

## Value

A tibble, parsed list, or httr2 response.

## Functions

- `zwift_profile()`: A rider's profile (`"me"` or a Zwift id).

- `zwift_activities()`: A rider's activities (paged).

- `zwift_activity()`: A single activity by id.

- `zwift_followers()`: A rider's followers.

- `zwift_followees()`: A rider's followees.

- `zwift_rideons()`: Ride Ons on an activity.

- `zwift_give_rideon()`: Give a Ride On (POST). Returns the raw
  response.

- `zwift_event()`: An event by id.

- `zwift_worlds()`: List of active worlds.

- `zwift_riders_in_world()`: Roster of riders currently in a world. Live
  position/power is protobuf on `/relay/worlds/{id}/players/{id}`; this
  JSON endpoint returns the roster only.
