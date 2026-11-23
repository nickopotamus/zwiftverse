# zwiftverse — development handoff

**Version:** 0.1.0 (pre-check)
**Last authored:** 2026-11-23
**Purpose of this doc:** bring a fresh session (Cowork or human) up to speed to
*test* the package against the live APIs and *continue* development without
re-deriving context.

---

## TL;DR status

An R package wrapping three unofficial Zwift-ecosystem APIs (Zwift game,
ZwiftPower, ZwiftRacing.app). Typed wrappers return tibbles; shared on-disk TTL
cache; roxygen docs; CI + pkgdown workflows; one vignette.

**What is done:** structure, code, cache, NAMESPACE, tests (offline), CI YAML,
pkgdown config, vignette.

**What is NOT done — the gate before trusting anything:**
- Never run under a real R. Authored in an environment with **no R toolchain**,
  so this is *static-checked only* — not `R CMD check`-clean, tests not
  executed, never called against a live endpoint.
- `man/` is **not** generated (roxygen tags present; run `devtools::document()`).
- Endpoint **field names are partly assumed** (see Risks). The vignette's
  `transmute()`/`hoist()` column names are placeholders to be pinned against
  real responses.

Treat v0.1.0 as "compiles in my head, needs a real run."

---

## First actions (ordered)

```r
# from the package root
install.packages(c("devtools","roxygen2","httr2","tibble","dplyr","rlang"))
devtools::document()      # generate man/ + refresh NAMESPACE from roxygen
devtools::test()          # offline tests: tibble converter + cache. Should pass.
devtools::check()         # expect a few NOTES/WARNINGS to clear — see below
```

**Anticipated `check()` findings and fixes:**
- Undocumented `...` on the `@describeIn` children → already documented on the
  parents (`zwift_get`, `zp_get`, `zr_get`); if roxygen still flags, add an
  explicit `@param ...` to each parent (harmless).
- `req_throttle(rate = …)` is **deprecated in httr2 ≥ 1.1** (still works, warns).
  Swap to `capacity`/`fill_time_s` in `R/zwiftracing.R::.zr_req()` once you
  confirm the installed httr2 version.
- `stats::setNames` in `zp_login()` — fully qualified, should be fine; if NOTE,
  add `@importFrom stats setNames`.
- Non-ASCII: README/vignette use em-dashes etc. (allowed); DESCRIPTION is clean.

**Then live smoke tests, easiest auth first:**
1. **ZR** (`ZR_AUTH` env var — simplest, single header). `zr_rider(zr_client(), <known_id>)`.
2. **Zwift** (`ZWIFT_USERNAME`/`ZWIFT_PASSWORD`). `zwift_profile(zwift_auth())`.
3. **ZP** — use `zp_set_cookie()` with a browser-copied `phpbb3_lswlk_sid`
   first; only test `zp_login()` (SSO scrape) after.

For each endpoint: call with `parse = "json"`, `glimpse()` the result, **record
the real field names**, then confirm the tibble shape with `parse = "tbl"`.

---

## Known risks & unverified assumptions

| # | Assumption | Source | How to verify |
|---|---|---|---|
| 1 | ZP result/`_view.json` fields: `zwid`, `position_in_cat`, `category`, `avg_wkg` | inferred | `zp_result(zp, id, parse="json")` then `str()` |
| 2 | ZR rider nests ratings under `race` (`current`/`max30`/`max90`, `rating`, `mixed$category`) | inferred from zpdatafetch | `zr_rider(zr, id, parse="json")` |
| 3 | ZR id field is `riderId` | inferred | same |
| 4 | ZR auth = raw key in `Authorization` (no `Bearer`) — **superseded, see results** | puckdoug/zpdatafetch source | first live ZR call |
| 5 | ZR base `https://api.zwiftracing.app/api` | puckdoug/zpdatafetch source | first live ZR call |
| 6 | ZR batch POST body = bare JSON array of ints, ≤1000 | source | `zr_riders()` live |
| 7 | Zwift auth: `secure.zwift.com/auth/realms/zwift/tokens/access/codes`, `client_id=Zwift_Mobile_Link`, password grant | well-established community value | `zwift_auth()` live (Zwift has migrated auth before — this is the single most likely breakage) |
| 8 | ZP cookie name `phpbb3_lswlk_sid` | source/community | inspect browser cookies on zwiftpower.com |
| 9 | `.zv_to_tbl()` flattening is correct for deeply nested real payloads | logic only | assert shapes in tests once fixtures exist |

Rule of thumb: anything marked "inferred" above must be confirmed before the
vignette or downstream analysis is trusted.

### Live verification results (2026-11-23)

| # | Result |
|---|---|
| 1 | ✅ **Confirmed.** `zwid`, `position_in_cat`, `category`, `avg_wkg`, `name` all present. Numbers come as `[value, flag]` pairs (value sometimes a string) → new `zp_unflag()`; vignette updated. |
| 2 | ❌ **Wrong — API moved to v2.** `race` now holds counts (`finishes/wins/podiums/dnfs`); the rating is `velo$race` (+ `velo$factors`). Legacy `live/max30/max90` ratings are under `/riders/{id}/overview` → `legacyRatings`. |
| 3 | ✅ `riderId`. |
| 4 | ❌ **Wrong.** Key goes in an `x-api-key` header (not `Authorization`, with or without `Bearer`). |
| 5 | ❌ v1 `/api/public/*` routes return 401 for this key; everything is `/api/v2/*`. Responses wrap as `{success, data}`. |
| 6 | ❌ No batch endpoint in v2 → `zr_riders()` loops (throttled, cached). |
| 7 | ✅ Legacy `tokens/access/codes` + `Zwift_Mobile_Link` still works. OIDC fallback kept. |
| 8 | ⚠️ Partly. `phpbb3_lswlk_sid` works for `api3.php`, but `cache3/*.json` is now behind **CloudFront signed cookies** (403 `MissingKey`). Fixed: `zp_get()` loads a logged-in page to obtain them (re-primed every 30 min). |

Other live findings, all fixed:
- Zwift accepts `"me"` only on `/api/profiles/me`; sub-resources (activities,
  followers, followees, rideons) 404 → wrappers now resolve `"me"` to the id.
- Zwift activity ids exceed 2^53 → parsed with `bigint_as_char = TRUE`.
- ZwiftPower `api3.php` serves JSON as `text/html` → parse with `check_type = FALSE`.

ZwiftRacing client rewritten for v2: `zr_rider`, `zr_rider_overview`,
`zr_rider_results`, `zr_rider_ranking`, `zr_rider_velo`, `zr_rider_power`,
`zr_riders`, `zr_event`, `zr_result` (event pens → one row per rider, incl.
`ratingBefore`/`rating`/`riderVelo.race`), `zr_club`, `zr_club_riders`
(0-based `?page=`, 50/page, auto-pages), `zr_routes`. Removed: `zr_post`,
`zr_categories`, `epoch` (v2 has no snapshot endpoint; use `zr_rider_velo()`).

Fixtures recorded for all 21 endpoints (scrubbed, arrays ≤25 at any depth,
~770 KB). 65 tests pass, 0 skip. Vignette pipeline (sections 1–3) run live
end-to-end on 2026-11-23.

---

## Recommended next step: fixture-based tests

The biggest fragility is parsing real payload shapes with no offline way to test
them. Fix that first:

1. Add **`httptest2`** (Suggests).
2. Make one authenticated call per endpoint and record with
   `httptest2::capture_requests({ ... })` → saves sanitised JSON fixtures under
   `tests/testthat/`.
3. **Scrub rider PII** from fixtures before committing (names, ids → synthetic).
4. Wrap the parsing tests in `with_mock_api()` so CI tests `.zv_to_tbl()` against
   real shapes **without credentials or network**.

This turns "I think the columns are right" into a regression guard and makes the
green CI badge meaningful.

---

## Backlog (prioritised)

**P0 — make it real**
- [x] `devtools::document()` — `man/` generated; NAMESPACE now roxygen-owned
      (export list identical to the hand-written one). *Commit pending: not yet
      a git repo.*
- [x] Pin real field names — Risks 1–3 verified; vignette rewritten + run live.
      → run `dev/smoke-live.R` + `dev/capture-fixtures.R`; `tests/testthat/test-fixtures.R`
      asserts the assumed names and will fail loudly where reality differs.
- [x] Confirm auth — 7 ✅, 8 ✅ (CloudFront fix), 4/5 fixed (v2 + `x-api-key`).
- [x] Fixture harness + offline parsing tests. **Deviation:** uses httr2's
      native `local_mocked_responses()` instead of httptest2 — httptest2 keys
      mocks on URL + POST-body hash, which breaks once rider ids in URLs/bodies
      are pseudonymised. Fixtures are recorded + scrubbed by
      `dev/capture-fixtures.R` (scrubber: `dev/scrub.R`); tests skip until
      fixtures exist. Harness verified with synthetic payloads.
- [~] Local `devtools::check()`: 0 errors / 0 warnings (only an environmental
      "unable to verify current time" note). Green Actions needs a GitHub repo.

Also done ahead of P1: `req_throttle(capacity=, fill_time_s=)`; `zr_riders()`
sorts/dedupes ids for a stable cache key; `zwift_auth()` falls back to the
OpenID Connect token endpoint if the legacy path 404s (Risk 7), records which
URL worked in `$.state$auth_url`, and gives a clear error on auth failure.

### Live testing quick-start

Put credentials + target ids in a gitignored `.Renviron` (vars documented at
the top of `dev/endpoints.R`), restart R, then from the package root:

```sh
Rscript dev/smoke-live.R        # pass/fail + field names per endpoint, no values
Rscript dev/capture-fixtures.R  # writes scrubbed fixtures -> tests/testthat/fixtures
Rscript -e 'devtools::test()'   # fixture tests now run instead of skipping
```

**P1 — completeness & robustness**
- [x] Swap `req_throttle(rate=)` → `capacity`/`fill_time_s` (httr2's
      `req_retry` already honours `Retry-After`).
- [x] Pagination: `zwift_activities`/`followers`/`followees` take `limit` as
      the total wanted and page internally at the server maximum (activities
      50, follows 200; larger → HTTP 400 `limit.too.large`). `limit = Inf` = all.
      Followers/followees now default to all. Multi-page + `parse = "json"`
      errors (one response can't represent several). Generic `.zv_paged()` +
      type-tolerant `.zv_bind()` in `R/utils.R`.
- [x] Zwift event results: `zwift_event_subgroups()`, `zwift_subgroup_results()`
      / `zwift_event_results()` (`/api/race-results/entries?event_subgroup_id=`,
      `{entries}`, paged at 50 — a 200-row page drew a 429),
      `zwift_subgroup_entrants()` / `zwift_event_entrants()`
      (`/api/events/subgroups/entrants/{id}?participation=signed_up&type=all`;
      `joined` is rejected). Verified live: 147 results across A–D matches
      ZwiftPower's 147 finishers.
- [x] ~~Cache key for `zr_riders`~~ — moot in v2 (per-rider requests).

**Added since P1 (2026-11-23):** `zp_segment_standings()` (api3
`segment_standings`, optional `team_id`); `zp_unflag()` now also handles the
sign-up `[code, value, percentile]` triples (value = element 2, verified);
vignette `climb-prediction` (pen entrants → ZR/ZP power curves → CP model →
climb time calibrated on a team's segment efforts, leave-one-out MAPE ≈ 11%).
Vignettes evaluate only when `ZV_LIVE_VIGNETTES=true`.

**P2 — polish**
- [ ] Token-refresh edge cases (clock skew, refresh-expiry races) in `zwift_auth`.
- [ ] Optional `memoise` in-session layer over the disk cache.
- [ ] README badges, `NEWS.md`, `LICENSE.md`, `URL`/`BugReports` in DESCRIPTION.
- [ ] pkgdown: set `url:`, enable GitHub Pages → `gh-pages`.

**P3 — distribution**
- [ ] Wrap examples in `\dontrun{}` (all need creds); add `@examples`.
- [ ] CRAN pre-flight if ever intended (unlikely given unofficial APIs — more
      likely r-universe / GitHub only).

---

## Architecture (so you don't have to reverse-engineer it)

- **`R/cache.R::.zv_fetch(req, parse, ttl)`** is the single choke point. Every
  low-level accessor builds an httr2 `req` and hands it here. It: bypasses on
  `parse="resp"`; else computes a cache key (`method + url + body` hash via
  `rlang::hash`), serves a fresh cache hit, otherwise performs → parses JSON
  (`simplifyVector/DataFrame + flatten`) → caches → returns tbl/json.
- **`.zv_to_tbl()`** (`R/utils.R`): data.frame → tibble; `{data:[...]}` envelope
  unwrapped; bare array → row-bind; single object → one-row tibble with nested
  fields as **list-columns** (user `tidyr::unnest_wider`/`hoist`).
- **Three auth models**, one per file: `zwift_auth()` (OAuth2 handle,
  auto-refresh, env `ZWIFT_USERNAME/PASSWORD`); `zp_session()` + cookie (env
  creds for SSO, or pasted sid); `zr_client()` (static key, env `ZR_AUTH`).
- **Typed wrappers forward `...`** to the low-level `*_get`, so `parse=`/`ttl=`
  flow through without per-wrapper plumbing.
- **TTL semantics:** `0`=off, `Inf`=permanent (immutable: completed results,
  historical `epoch`), `n`=seconds. Per-API defaults via
  `options(zwiftverse.ttl_zwift/zp/zr)`.

## Provenance

Endpoints verified by reading **github.com/puckdoug/zpdatafetch** (the Python
reference for all three APIs). Zwift game-API surface cross-referenced to
**github.com/strukturunion-mmw/zwift-api-documentation**. Nothing here used a
leaked key — ZR is wired for the user's own pending key.

## Compliance / security (do not skip)

- Zwift + ZP auth use the athlete's **real password**, not a revocable token —
  never commit creds; use env vars or `keyring`. Fixtures must be PII-scrubbed.
- Data is **GDPR-consent-gated**: non-consenting riders simply won't appear;
  don't treat absence as error.
- Unofficial APIs: expect breakage on upstream releases; fine for personal/
  research use, think harder before anything that redistributes others' data.
