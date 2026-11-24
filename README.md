# zwiftverse

<!-- badges: start -->

[![R-CMD-check](https://github.com/nickopotamus/zwiftverse/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/nickopotamus/zwiftverse/actions/workflows/R-CMD-check.yaml) [![pkgdown](https://github.com/nickopotamus/zwiftverse/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/nickopotamus/zwiftverse/actions/workflows/pkgdown.yaml) [![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

<!-- badges: end -->

Tidy [httr2](https://httr2.r-lib.org) clients for three unofficial [Zwift](https://www.zwift.com/)-ecosystem APIs.

Every endpoint returns a tibble. An on-disk TTL cache keeps you from re-fetching stable data.

| API | Auth | Base |
|------------------------|------------------------|------------------------|
| Zwift game | OAuth2 password grant (`Zwift_Mobile_Link`) | `us-or-rly101.zwift.com` |
| ZwiftPower | phpBB/SSO session cookie | `zwiftpower.com` |
| ZwiftRacing.app | static key in `x-api-key` header | `api.zwiftracing.app/api/v2` |

Note that this is entirely **unofficial & reverse-engineered.** None of these are sanctioned APIs. The Zwift and ZwiftPower flows need *your own* Zwift credentials.

Personal data is all GDPR-consent-gated - you only see riders who have opted in.

Note that API endpoints can change without notice! Raise an issue if they stop working.

## Install

``` r
# install.packages("pak")
pak::pak("nickopotamus/zwiftverse")
```

## Credentials

Put these in `~/.Renviron` (never in code you commit), then restart R:

```         
ZWIFT_USERNAME=you@example.com
ZWIFT_PASSWORD=...
ZP_SID=...                     # phpbb3_lswlk_sid cookie from zwiftpower.com
ZR_AUTH=your-zwiftracing-key   # sent as the x-api-key header
```

- **Zwift** uses your own Zwift login.
- **ZwiftPower:** log in at zwiftpower.com in a browser, then copy the value of the `phpbb3_lswlk_sid` cookie (browser dev tools → Storage / Application → Cookies). `zp_login()` can log in for you instead, but it breaks more often.
- **ZwiftRacing.app** needs an API key. "Hobby" level API access can be accessed [by supporting ZwiftRacing.app](https://zwiftracing.app/support), then flagging this to Tim on [Discord](https://discord.gg/yxPSpdxYmg). A standard key works with the v2 endpoints this package uses (`/api/v2/...`); the older `/api/public/...` endpoints and `/api/v2/public/categories` need a different access level and return 401 with one.
- **Zwift's status page** (`zwift_status()`) needs no credentials.

## Usage

``` r
library(zwiftverse)

## Zwift game API ----------------------------------------------------
za  <- zwift_auth()                        # token auto-refreshes
me  <- zwift_profile(za)                   # your profile (one-row tibble)
oth <- zwift_profile(za, 1234567)          # another rider's public profile
act <- zwift_activities(za, limit = Inf)   # whole history, auto-paged
fol <- zwift_followers(za)                 # all followers (auto-paged)
res <- zwift_event_results(za, 5795672)    # official results, all subgroups
ent <- zwift_event_entrants(za, 5795672)   # sign-ups, all subgroups
wld <- zwift_riders_in_world(za, 1)        # roster currently in Watopia
raw <- zwift_get(za, "/api/profiles/me/activities/", list(limit = 5))
zwift_status()                             # is Zwift up? (no login needed)
zwift_status("unresolved")                 # open incidents, if any

## ZwiftPower --------------------------------------------------------
zp   <- zp_set_cookie(zp_session(), "PASTE_phpbb3_lswlk_sid")  # robust path
# zp <- zp_login(zp_session())                                 # or SSO (brittle)
res  <- zp_result(zp, 3590800)                    # finishers
team <- zp_team(zp, 456)                          # team roster with category + recent power
fts  <- zp_sprints(zp, 3590800)                   # every rider's time + power on each segment
rr   <- zp_analysis(zp, 3590800, 1234567)         # race report: per-second power/HR/altitude
pen  <- zp_event_analysis(zp, 3590800, pen = "B") # ...for every finisher in pen B

## ZwiftRacing.app ---------------------------------------------------
zr <- zr_client()
r1 <- zr_rider(zr, 1234567)                    # vELO rating in velo$race
lg <- zr_rider_overview(zr, 1234567)           # legacy ratings: live / max30 / max90
rr <- zr_rider_results(zr, 1234567, days = 90) # one row per race, last 90 days
ev <- zr_result(zr, 5800908)                   # one row per rider, all pens
cm <- zr_club_riders(zr, 456)                  # all pages
rb <- zr_riders(zr, c(1234567, 2345678))       # one request per rider (no v2 batch)
```

Nested JSON arrives as list-columns:

``` r
library(tidyr)
zr_rider(zr, 1234567) |> hoist(velo, velo_race = "race")
```

## A closer look at three functions

### `zp_team()`: a ZwiftPower team roster

One row per team member (all members, not only recent racers):

| Column | Meaning |
|------------------------------------|------------------------------------|
| `zwid`, `name`, `flag`, `age` | Zwift id, name, country, age band (e.g. `"50+"`) |
| `div`, `divw` | ZwiftPower category, open and women's: `5` = A+, `10` = A, `20` = B, `30` = C, `40` = D, `0` = none |
| `ftp`, `w` | ZwiftPower's FTP estimate (W) and weight (kg) |
| `h_1200_watts`, `h_1200_wkg`, `h_15_watts`, `h_15_wkg` | recent 20-minute and 15-second bests |
| `rank`, `skill` | ZwiftPower ranking points (lower is better, blank without recent races) and skill score |
| `distance`, `climbed`, `time`, `energy` | lifetime Zwift totals (distance and climbing in metres) |
| `status` | team role, e.g. `Owner`, `Moderator` (blank for members) |

``` r
zp_team(zp, 456) |>
  zp_unflag() |>                          # [value, flag] pairs -> numbers
  count(div)                              # riders per category

zp_team(zp, 456) |>
  zp_unflag() |>
  filter(div == 20) |>                    # the B riders
  arrange(desc(as.numeric(h_1200_wkg))) |>
  select(name, ftp, w, h_1200_wkg)
```

### `zp_sprints()`: segment results for one race

One row per finisher (all categories). For every timed segment on the route (sprints, KOMs, the finish climb) it gives that rider's effort, in three column families named by **segment id**:

| Column | Meaning |
|------------------------------------|------------------------------------|
| `msec.<id>` | time through the segment, in **seconds** despite the name |
| `watts.<id>`, `wkg.<id>` | average power and w/kg through it |

Look up segment names with `zp_primes()` (`sprint_id`, `name`). A segment that wasn't on a rider's route is `NA`. Each id is also the key for `zp_segment_standings()`, which lists riders' best efforts on that segment (a whole team's, or the global top \~2,000).

``` r
seg_names <- zp_primes(zp, 3590800) |> distinct(sprint_id, name)

zp_sprints(zp, 3590800) |>
  zp_unflag() |>
  filter(category == "B") |>
  transmute(name, finish_s = as.numeric(msec.37), finish_wkg = as.numeric(wkg.37)) |>
  arrange(finish_s)                       # fastest through segment 37
```

### `zr_rider_results()`: a rider's race history on ZwiftRacing.app

One row per race in the last `days` days (default 365). Nested fields are flattened into dotted column names, in groups:

| Column group | What it holds |
|------------------------------------|------------------------------------|
| `event.*` | `eventId`, `time`, `title`, `type`, `routeName`, `distance`, `elevation` |
| `place.*` | `positionInCategory`, `penTotal`, `didNotFinish`, `disqualified` |
| `race.*` | the rider's numbers that day: `time`, `gap`, `weight`, `wkgAvg`, and best w/kg for 5 s – 20 min (`wkg5` ... `wkg1200`) |
| `sensor.*` | `powerType`, `trainerDifficulty`, `heartRateMonitor` |
| `velo.elo.*` | vELO rating `before` / `after`, `expectedPosition`, and per-ability changes (`factors.sprint.*`, `factors.climb.*`, ...) |
| `legacy.*` | old-style ZwiftRacing rating: `ratingBefore`, `rating`, `ratingDelta` |
| `classement.*`, `timeCut.*` | ZwiftRacing league points and time-cut data |

``` r
zr_rider_results(zr, 1234567, days = 90) |>
  transmute(date = as.POSIXct(event.time, origin = "1970-01-01"),
            race = event.title, pos = place.positionInCategory, of = place.penTotal,
            wkg = race.wkgAvg, velo_change = velo.elo.after - velo.elo.before) |>
  arrange(desc(date))
```

## Caching

The cache is on by default and keyed on method + URL + body. Entries are stored on disk and, for the rest of the R session, in memory too. TTL (seconds): `0` = off, `Inf` = permanent (immutable data such as completed results).

``` r
options(
  zwiftverse.cache     = TRUE,         # master switch
  zwiftverse.cache_memory = TRUE,      # in-session memory copy of hits
  zwiftverse.ttl_zwift = 900,          # per-API defaults
  zwiftverse.ttl_zp    = 3600,
  zwiftverse.ttl_zr    = 3600
)

zr_result(zr, 5800908, ttl = Inf)      # per-call override (finished race)
zv_cache_info()                        # what's cached
zv_cache_clear()                       # wipe it
```

## Endpoint coverage

- **Zwift:** `profile`, `activities`, `activity`, `followers`, `followees` (list endpoints auto-page: `limit` is the total wanted, `Inf` = all), `rideons` (+ `give_rideon`), `event`, `event_subgroups`, `event_results`, `subgroup_results`, `event_entrants`, `subgroup_entrants`, `worlds`, `riders_in_world`, plus `zwift_get`/`zwift_post`. Service status: `zwift_status()` (`status`, `components`, `unresolved`, `incidents`, `maintenance`).
- **ZwiftPower:** `profile`, `result`, `signups`, `team`, `event_list`, `result_list`, `team_riders`, `team_list`, `sprints`, `primes`, `segment_standings`, `analysis`, `event_analysis`, `league_list`, `league_results`, `league_team_standings`, plus `zp_get`.
- **ZwiftRacing.app (v2):** `rider`, `rider_overview`, `rider_results`, `rider_ranking`, `rider_velo`, `rider_power`, `riders`, `event`, `result`, `club`, `club_riders`, `routes`, plus `zr_get`.

## Acknowledgements

- [zpdatafetch](https://github.com/puckdoug/zpdatafetch) by Doug Morris (puckdoug), a Python library for the same three APIs plus Zwift's status page. Its source was the reference used to find and check the endpoints and auth flows here. zwiftverse is an independent R implementation and doesn't share its code.
- [zwift-api-documentation](https://github.com/strukturunion-mmw/zwift-api-documentation) by strukturunion-mmw, for the Zwift game API.
