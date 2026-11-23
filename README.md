# zwiftverse

Tidy [httr2](https://httr2.r-lib.org) clients for three unofficial
Zwift-ecosystem APIs. Every endpoint returns a **tibble**; an on-disk TTL cache
keeps you from re-fetching stable data.

| API | Auth | Base |
|---|---|---|
| Zwift game | OAuth2 password grant (`Zwift_Mobile_Link`) | `us-or-rly101.zwift.com` |
| ZwiftPower | phpBB/SSO session cookie | `zwiftpower.com` |
| ZwiftRacing.app | static `Authorization` key | `api.zwiftracing.app/api` |

> **Unofficial & reverse-engineered.** None of these are sanctioned APIs. The
> Zwift and ZwiftPower flows need *your own* Zwift credentials. Personal data is
> GDPR-consent-gated — you only see riders who have opted in. Endpoints can
> change without notice.

## Install

```r
# install.packages("devtools")
devtools::install_local("zwiftverse")   # or install.packages("zwiftverse_0.1.0.tar.gz", repos = NULL)
devtools::document("zwiftverse")         # regenerate man/ from the roxygen tags
```

## Credentials

```r
Sys.setenv(ZWIFT_USERNAME = "you@example.com", ZWIFT_PASSWORD = "…")
Sys.setenv(ZR_AUTH = "your-zwiftracing-key")   # raw header value, no "Bearer"
```

## Usage

```r
library(zwiftverse)

## Zwift game API ----------------------------------------------------
za  <- zwift_auth()                    # token auto-refreshes
me  <- zwift_profile(za)               # your profile (one-row tibble)
oth <- zwift_profile(za, 1234567)      # another rider's public profile
act <- zwift_activities(za, 1234567, limit = 50)
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
r1 <- zr_rider(zr, 1234567)
rb <- zr_riders(zr, c(1234567, 2345678, 3456789))   # batch POST, 1 request
cl <- zr_club(zr, 456)
```

Nested JSON arrives as list-columns:

```r
library(tidyr)
zr_rider(zr, 1234567) |> unnest_wider(race)
```

## Caching

The cache is on by default and keyed on method + URL + body. TTL (seconds):
`0` = off, `Inf` = permanent (immutable data such as completed results or a
historical `epoch` snapshot).

```r
options(
  zwiftverse.cache     = TRUE,         # master switch
  zwiftverse.ttl_zwift = 900,          # per-API defaults
  zwiftverse.ttl_zp    = 3600,
  zwiftverse.ttl_zr    = 3600
)

zr_rider(zr, 1234567, ttl = Inf)       # per-call override
zv_cache_info()                        # what's cached
zv_cache_clear()                       # wipe it
```

## Endpoint coverage

- **Zwift:** `profile`, `activities`, `activity`, `followers`, `followees`,
  `rideons` (+ `give_rideon`), `event`, `worlds`, `riders_in_world`, plus
  `zwift_get`/`zwift_post`.
- **ZwiftPower:** `profile`, `result`, `signups`, `team`, `event_list`,
  `result_list`, `team_riders`, `team_list`, `sprints`, `primes`, `league_list`,
  `league_results`, `league_team_standings`, plus `zp_get`.
- **ZwiftRacing.app:** `rider` (+ epoch), `riders` (batch), `result`, `club`,
  `categories`, plus `zr_get`/`zr_post`.
