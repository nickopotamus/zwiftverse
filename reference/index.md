# Package index

## Zwift game API

OAuth2-authenticated access to profiles, activities, events and worlds.

- [`zwift_auth()`](zwift_auth.md) : Authenticate against the Zwift game
  API
- [`zwift_get()`](zwift_get.md) [`zwift_profile()`](zwift_get.md)
  [`zwift_activities()`](zwift_get.md)
  [`zwift_activity()`](zwift_get.md) [`zwift_followers()`](zwift_get.md)
  [`zwift_followees()`](zwift_get.md) [`zwift_rideons()`](zwift_get.md)
  [`zwift_give_rideon()`](zwift_get.md) [`zwift_event()`](zwift_get.md)
  [`zwift_event_subgroups()`](zwift_get.md)
  [`zwift_subgroup_results()`](zwift_get.md)
  [`zwift_event_results()`](zwift_get.md)
  [`zwift_subgroup_entrants()`](zwift_get.md)
  [`zwift_event_entrants()`](zwift_get.md)
  [`zwift_worlds()`](zwift_get.md)
  [`zwift_riders_in_world()`](zwift_get.md) : Low-level Zwift GET
- [`zwift_post()`](zwift_post.md) : Low-level Zwift POST

## ZwiftPower

Session-cookie access to results, teams, leagues and segment data.

- [`zp_session()`](zp_session.md) : Create a ZwiftPower session

- [`zp_set_cookie()`](zp_set_cookie.md) : Set the ZwiftPower session
  cookie directly

- [`zp_login()`](zp_login.md) : Log in to ZwiftPower via Zwift SSO (best
  effort)

- [`zp_get()`](zp_get.md) [`zp_profile()`](zp_get.md)
  [`zp_result()`](zp_get.md) [`zp_signups()`](zp_get.md)
  [`zp_team()`](zp_get.md) [`zp_event_list()`](zp_get.md)
  [`zp_result_list()`](zp_get.md) [`zp_team_riders()`](zp_get.md)
  [`zp_team_list()`](zp_get.md) [`zp_sprints()`](zp_get.md)
  [`zp_primes()`](zp_get.md) [`zp_segment_standings()`](zp_get.md)
  [`zp_league_list()`](zp_get.md) [`zp_league_results()`](zp_get.md)
  [`zp_league_team_standings()`](zp_get.md) : Low-level ZwiftPower GET

- [`zp_unflag()`](zp_unflag.md) :

  Unwrap ZwiftPower `[value, flag]` columns

- [`zp_analysis()`](zp_analysis.md)
  [`zp_event_analysis()`](zp_analysis.md) : Race-report data streams
  from ZwiftPower

## ZwiftRacing.app

Key-authenticated rider ratings, results and club rosters.

- [`zr_client()`](zr_client.md) : Create a ZwiftRacing.app client
- [`zr_get()`](zr_get.md) [`zr_rider()`](zr_get.md)
  [`zr_rider_overview()`](zr_get.md) [`zr_rider_results()`](zr_get.md)
  [`zr_rider_ranking()`](zr_get.md) [`zr_rider_velo()`](zr_get.md)
  [`zr_rider_power()`](zr_get.md) [`zr_riders()`](zr_get.md)
  [`zr_event()`](zr_get.md) [`zr_result()`](zr_get.md)
  [`zr_club()`](zr_get.md) [`zr_club_riders()`](zr_get.md)
  [`zr_routes()`](zr_get.md) : Low-level ZwiftRacing.app GET

## Caching

On-disk TTL cache controls.

- [`zv_cache_clear()`](zv_cache_clear.md) : Clear the on-disk cache.
- [`zv_cache_dir()`](zv_cache_dir.md) : Path to the cache directory
  (created on demand).
- [`zv_cache_enabled()`](zv_cache_enabled.md) : Is caching currently
  enabled?
- [`zv_cache_info()`](zv_cache_info.md) : Summarise the cache contents.
