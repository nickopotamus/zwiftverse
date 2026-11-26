# Package index

## Zwift game API

OAuth2-authenticated access to profiles, activities, events and worlds.

- [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  : Authenticate against the Zwift game API
- [`zwift_get()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_profile()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_activities()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_activity()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_followers()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_followees()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_rideons()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_event()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_event_subgroups()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_subgroup_results()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_event_results()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_subgroup_entrants()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_event_entrants()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_worlds()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  [`zwift_riders_in_world()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  : Low-level Zwift GET
- [`zwift_status()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_status.md)
  : Zwift service status

## ZwiftPower

Session-cookie access to results, teams, leagues and segment data.

- [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md)
  : Create a ZwiftPower session

- [`zp_set_cookie()`](https://nickopotamus.github.io/zwiftverse/reference/zp_set_cookie.md)
  : Set the ZwiftPower session cookie directly

- [`zp_login()`](https://nickopotamus.github.io/zwiftverse/reference/zp_login.md)
  : Log in to ZwiftPower via Zwift SSO (best effort)

- [`zp_get()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_profile()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_result()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_signups()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_team()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_event_list()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_result_list()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_team_riders()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_team_list()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_sprints()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_primes()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_segment_standings()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_league_list()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_league_results()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  [`zp_league_team_standings()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
  : Low-level ZwiftPower GET

- [`zp_unflag()`](https://nickopotamus.github.io/zwiftverse/reference/zp_unflag.md)
  :

  Unwrap ZwiftPower `[value, flag]` columns

- [`zp_analysis()`](https://nickopotamus.github.io/zwiftverse/reference/zp_analysis.md)
  [`zp_event_analysis()`](https://nickopotamus.github.io/zwiftverse/reference/zp_analysis.md)
  : Race-report data streams from ZwiftPower

- [`zp_power_curve()`](https://nickopotamus.github.io/zwiftverse/reference/zp_power_curve.md)
  : A rider's power curve from ZwiftPower

## ZwiftRacing.app

Key-authenticated rider ratings, results and club rosters.

- [`zr_client()`](https://nickopotamus.github.io/zwiftverse/reference/zr_client.md)
  : Create a ZwiftRacing.app client
- [`zr_get()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_riders()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider_overview()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider_results()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider_ranking()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider_velo()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_rider_power()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_event()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_result()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_zp_result()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_club()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_club_riders()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_categories()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_route_weights()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  [`zr_routes()`](https://nickopotamus.github.io/zwiftverse/reference/zr_get.md)
  : Low-level ZwiftRacing.app request

## Across APIs

Helpers that combine ZwiftRacing.app and ZwiftPower data.

- [`zv_rider_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_rider_cp.md)
  : A rider's critical power and W'
- [`zv_signups_cp()`](https://nickopotamus.github.io/zwiftverse/reference/zv_signups_cp.md)
  : Critical power and W' for everyone signed up to a race

## Caching

On-disk TTL cache controls.

- [`zv_cache_clear()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_clear.md)
  : Clear the cache.
- [`zv_cache_dir()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_dir.md)
  : Path to the cache directory (created on demand).
- [`zv_cache_enabled()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_enabled.md)
  : Is caching currently enabled?
- [`zv_cache_info()`](https://nickopotamus.github.io/zwiftverse/reference/zv_cache_info.md)
  : Summarise the cache contents.
