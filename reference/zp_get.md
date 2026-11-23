# Low-level ZwiftPower GET

Low-level ZwiftPower GET

## Usage

``` r
zp_get(s, url, parse = "tbl", ttl = .zv_ttl("zp"))

zp_profile(s, zwift_id, ...)

zp_result(s, race_id, ...)

zp_signups(s, race_id, ...)

zp_team(s, team_id, ...)

zp_event_list(s, ...)

zp_result_list(s, ...)

zp_team_riders(s, team_id, ...)

zp_team_list(s, ...)

zp_sprints(s, race_id, ...)

zp_primes(s, race_id, category = "", prime_type = "", ...)

zp_league_list(s, ...)

zp_league_results(s, id, ...)

zp_league_team_standings(s, id, ...)
```

## Arguments

- s:

  A [`zp_session()`](zp_session.md).

- url:

  A full URL or a path under `zwiftpower.com`.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

- ttl:

  Cache time-to-live in seconds (`0` = off, `Inf` = permanent).

- zwift_id:

  Zwift rider id.

- ...:

  For the typed wrappers, further arguments forwarded to `zp_get()`.

- race_id:

  ZwiftPower event id.

- team_id:

  ZwiftPower team id.

- category, prime_type:

  Optional ZwiftPower prime filters.

- id:

  League / league-event id.

## Value

A tibble, parsed list, or httr2 response.

## Functions

- `zp_profile()`: Rider profile (all data).

- `zp_result()`: Event results.

- `zp_signups()`: Event signups.

- `zp_team()`: Team roster.

- `zp_event_list()`: Upcoming event list.

- `zp_result_list()`: Recent results list.

- `zp_team_riders()`: Team riders (api3).

- `zp_team_list()`: List of teams (api3).

- `zp_sprints()`: Fastest-through-segment (FTS) data for an event.

- `zp_primes()`: Prime (intermediate sprint/KOM) results for an event.

- `zp_league_list()`: List of leagues.

- `zp_league_results()`: League event results.

- `zp_league_team_standings()`: League team event standings.
