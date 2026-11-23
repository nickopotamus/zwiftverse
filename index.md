# zwiftverse

Tidy [httr2](https://httr2.r-lib.org) clients for three unofficial
Zwift-ecosystem APIs. Every endpoint returns a **tibble**; an on-disk
TTL cache keeps you from re-fetching stable data.

| API | Auth | Base |
|----|----|----|
| Zwift game | OAuth2 password grant (`Zwift_Mobile_Link`) | `us-or-rly101.zwift.com` |
| ZwiftPower | phpBB/SSO session cookie | `zwiftpower.com` |
| ZwiftRacing.app | static key in `x-api-key` header | `api.zwiftracing.app/api/v2` |

> **Unofficial & reverse-engineered.** None of these are sanctioned
> APIs. The Zwift and ZwiftPower flows need *your own* Zwift
> credentials. Personal data is GDPR-consent-gated — you only see riders
> who have opted in. Endpoints can change without notice.

## Install

``` r

# install.packages("devtools")
devtools::install_local("zwiftverse")   # or install.packages("zwiftverse_0.1.0.tar.gz", repos = NULL)
devtools::document("zwiftverse")         # regenerate man/ from the roxygen tags
```

## Credentials

``` r

Sys.setenv(ZWIFT_USERNAME = "you@example.com", ZWIFT_PASSWORD = "…")
Sys.setenv(ZR_AUTH = "your-zwiftracing-key")   # sent as the x-api-key header
```

## Usage

``` r

library(zwiftverse)

## Zwift game API ----------------------------------------------------
za  <- zwift_auth()                    # token auto-refreshes
me  <- zwift_profile(za)               # your profile (one-row tibble)
oth <- zwift_profile(za, 1234567)      # another rider's public profile
act <- zwift_activities(za, limit = Inf)   # whole history, auto-paged
fol <- zwift_followers(za)             # all followers (auto-paged)
res <- zwift_event_results(za, 5795672)  # official results, all subgroups
ent <- zwift_event_entrants(za, 5795672) # sign-ups, all subgroups
wld <- zwift_riders_in_world(za, 1)    # roster currently in Watopia
raw <- zwift_get(za, "/api/profiles/me/activities/", list(limit = 5))  # escape hatch

## ZwiftPower --------------------------------------------------------
zp   <- zp_set_cookie(zp_session(), "PASTE_phpbb3_lswlk_sid")  # robust path
# zp <- zp_login(zp_session())                                 # or SSO (brittle)
res  <- zp_result(zp, 3590800)         # finishers
team <- zp_team(zp, 456)
fts  <- zp_sprints(zp, 3590800)

## ZwiftRacing.app ---------------------------------------------------
zr <- zr_client()
r1 <- zr_rider(zr, 1234567)                  # vELO rating in velo$race
lg <- zr_rider_overview(zr, 1234567)         # legacy ratings: live / max30 / max90
rr <- zr_rider_results(zr, 1234567, days = 90)
ev <- zr_result(zr, 5800908)                 # one row per rider, all pens
cm <- zr_club_riders(zr, 456)                # all pages
rb <- zr_riders(zr, c(1234567, 2345678))     # one request per rider (no v2 batch)
```

Nested JSON arrives as list-columns:

``` r

library(tidyr)
zr_rider(zr, 1234567) |> hoist(velo, velo_race = "race")
```

## Caching

The cache is on by default and keyed on method + URL + body. TTL
(seconds): `0` = off, `Inf` = permanent (immutable data such as
completed results).

``` r

options(
  zwiftverse.cache     = TRUE,         # master switch
  zwiftverse.ttl_zwift = 900,          # per-API defaults
  zwiftverse.ttl_zp    = 3600,
  zwiftverse.ttl_zr    = 3600
)

zr_result(zr, 5800908, ttl = Inf)      # per-call override (finished race)
zv_cache_info()                        # what's cached
zv_cache_clear()                       # wipe it
```

## Endpoint coverage

- **Zwift:** `profile`, `activities`, `activity`, `followers`,
  `followees` (list endpoints auto-page: `limit` is the total wanted,
  `Inf` = all), `rideons` (+ `give_rideon`), `event`, `event_subgroups`,
  `event_results`, `subgroup_results`, `event_entrants`,
  `subgroup_entrants`, `worlds`, `riders_in_world`, plus
  `zwift_get`/`zwift_post`.
- **ZwiftPower:** `profile`, `result`, `signups`, `team`, `event_list`,
  `result_list`, `team_riders`, `team_list`, `sprints`, `primes`,
  `league_list`, `league_results`, `league_team_standings`, plus
  `zp_get`.
- **ZwiftRacing.app (v2):** `rider`, `rider_overview`, `rider_results`,
  `rider_ranking`, `rider_velo`, `rider_power`, `riders`, `event`,
  `result`, `club`, `club_riders`, `routes`, plus `zr_get`.
