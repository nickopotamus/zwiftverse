# Predicting a pen's times up a KOM

**Question:** before a race, who in my pen is likely to get up the big
climb fastest, and how long will it take them?

The recipe uses all three APIs:

1.  **Zwift** — who is signed up to the pen.
2.  **ZwiftPower** — a team’s real efforts on the climb, to learn how
    w/kg turns into time on *this* segment; plus each entrant’s sign-up
    power numbers.
3.  **ZwiftRacing.app** — each entrant’s recent power curve.

The worked example is Zwift Racing League event `5811034` (Muir and the
Mountain), pen B, and the climb is ZwiftPower segment `13` — the
**Watopia Epic KOM (forward)**. Change the four values below to reuse it
for any race.

``` r

library(zwiftverse)
library(dplyr)
library(tidyr)
library(ggplot2)

event_id   <- 5811034   # Zwift / ZwiftPower event id
pen        <- "B"       # subgroup label
segment_id <- 13        # ZwiftPower segment id (see zp_primes()$sprint_id)
team_id    <- 9976      # ZwiftPower team whose efforts calibrate the model

za <- zwift_auth()
zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
zr <- zr_client()
```

## 1. Who is racing in the pen

Zwift’s own entrant list is the authority on who is signed up. Each
subgroup (pen) has its own id:

``` r

pens <- zwift_event_subgroups(za, event_id)
pens |> select(id, subgroupLabel, eventSubgroupStart, totalEntrantCount)

pen_id <- pens$id[pens$subgroupLabel == pen]

entrants <- zwift_subgroup_entrants(za, pen_id) |>
  transmute(zwid = id, rider = paste(firstName, lastName),
            weight_kg = weight / 1000)
nrow(entrants)
```

ZwiftPower’s sign-up list adds the team and ZwiftPower’s own 5- and
20-minute bests. It labels pens 1–5 rather than A–E:

``` r

zp_pen <- match(pen, LETTERS)

zp_signup <- zp_signups(zp, event_id) |>
  zp_unflag() |>
  filter(label == zp_pen) |>
  transmute(zwid = as.integer(zwid), team = trimws(tname),
            zp_wkg5 = as.numeric(cp_300_wkg), zp_wkg20 = as.numeric(cp_1200_wkg))

field <- entrants |> left_join(zp_signup, by = "zwid")
field |> count(team, sort = TRUE)
```

## 2. How w/kg becomes time on this climb

Rather than simulating Zwift’s physics (gradient profile, drafting, bike
choice), learn the relationship from real races.
[`zp_segment_standings()`](https://nickopotamus.github.io/zwiftverse/reference/zp_get.md)
returns every best effort a team’s riders have set on the segment:
elapsed time and average w/kg.

``` r

team_efforts <- zp_segment_standings(zp, segment_id, team_id) |>
  zp_unflag() |>
  transmute(zwid, elapsed = as.numeric(elapsed), wkg = as.numeric(wkg),
            when = as.POSIXct(date, origin = "1970-01-01")) |>
  filter(elapsed > 0, wkg > 0)

nrow(team_efforts)
summary(team_efforts$elapsed / 60)
```

On a long climb, time falls as a power law of w/kg. A straight line on
log–log axes captures it:

``` r

climb_fit <- lm(log(elapsed) ~ log(wkg), data = team_efforts)
summary(climb_fit)$r.squared
coef(climb_fit)

# time (s) for a given average w/kg on this segment
climb_time <- function(wkg) exp(predict(climb_fit, data.frame(wkg = wkg)))

ggplot(team_efforts, aes(wkg, elapsed / 60)) +
  geom_point(alpha = 0.5) +
  geom_function(fun = function(x) climb_time(x) / 60, colour = "firebrick") +
  scale_x_log10() + scale_y_log10() +
  labs(x = "Average w/kg on segment (log)", y = "Time (min, log)",
       title = sprintf("Segment %d: team %d's best efforts", segment_id, team_id)) +
  theme_minimal()
```

The exponent is shallower than −1: doubling w/kg doesn’t halve the time,
because rolling resistance and air drag don’t scale with power (and race
efforts include some drafting).

## 3. Each rider’s power curve

ZwiftRacing.app holds each rider’s power curve at 5 s – 20 min in two
flavours: `d90` (raw best of the last 90 days) and `live` (a
current-form estimate in which older bests decay). `live` is the better
guide to what a rider can do *now*, so it drives the model. One request
per rider:

``` r

zr_curve <- function(id) {
  j <- tryCatch(zr_rider_power(zr, id, parse = "json"), error = function(e) NULL)
  cv <- j$data$curve
  if (is.null(cv) || !NROW(cv)) return(NULL)
  tibble(zwid = id, sec = cv$durationSec, wkg = cv$live.wkg)
}

# 5- and 20-minute points, one row per rider
zr_points <- function(ids) {
  bind_rows(lapply(unique(ids), zr_curve)) |>
    filter(sec %in% c(300, 1200)) |>
    pivot_wider(names_from = sec, values_from = wkg, names_prefix = "w") |>
    rename(zr_wkg5 = w300, zr_wkg20 = w1200)
}

field <- field |> left_join(zr_points(field$zwid), by = "zwid")
sum(!is.na(field$zr_wkg20))   # entrants with a ZwiftRacing curve
```

## 4. From a power curve to a climb time

The climb takes longer than 20 minutes — beyond the longest measured
duration — so extrapolate with the two-parameter **critical power**
model, P(t) = CP + W′/t, fitted exactly through the 5- and 20-minute
points:

``` r

sustainable <- function(p5, p20, t) {
  w_prime <- (p5 - p20) / (1 / 300 - 1 / 1200)   # work capacity above CP (J/kg)
  cp <- p20 - w_prime / 1200
  cp + w_prime / t
}
```

A rider’s climb time is the duration *t* at which the w/kg they hold for
*t* seconds gets them up the climb in exactly *t* seconds. Riders in a
race don’t climb at 100% of their curve, so scale it by a **race-day
fraction** *k* (estimated in the next section):

``` r

predict_climb <- function(p5, p20, k = 1) {
  if (anyNA(c(p5, p20)) || p5 <= p20 || p20 <= 0) return(NA_real_)
  f <- function(t) t - climb_time(k * sustainable(p5, p20, t))
  tryCatch(uniroot(f, c(300, 7200))$root, error = function(e) NA_real_)
}
```

## 5. Calibrate against the team’s real efforts

For each of the reference team’s riders we know both their actual time
up the climb and their current power curve. Comparing the w/kg they
*actually* held with what their curve says they *could* hold for that
long gives *k*. Only use efforts from the last year — older ones were
set by a fitter (or less fit) version of the rider than today’s curve
describes:

``` r

cal <- team_efforts |>
  filter(when > Sys.time() - 365 * 86400) |>
  inner_join(zr_points(team_efforts$zwid), by = "zwid") |>
  filter(zr_wkg5 > zr_wkg20) |>
  mutate(frac = wkg / sustainable(zr_wkg5, zr_wkg20, elapsed))

k <- median(cal$frac)
c(n = nrow(cal), k = round(k, 3), sd = round(sd(cal$frac), 3))
```

How good are the predictions? Leave each effort out, re-estimate *k*
from the rest, and predict it:

``` r

cal$loo <- vapply(seq_len(nrow(cal)), function(i)
  predict_climb(cal$zr_wkg5[i], cal$zr_wkg20[i], k = median(cal$frac[-i])), numeric(1))

cal |>
  summarise(n = n(),
            bias_s = mean(loo - elapsed),
            mae_s  = mean(abs(loo - elapsed)),
            mape   = mean(abs(loo - elapsed) / elapsed))

ggplot(cal, aes(elapsed / 60, loo / 60)) +
  geom_abline(linetype = 2, colour = "grey50") +
  geom_point() +
  coord_equal() +
  labs(x = "Actual time (min)", y = "Predicted time (min, leave-one-out)",
       title = "Reference team: predicted vs actual, last 12 months") +
  theme_minimal()
```

Expect individual predictions to be good to roughly the MAPE above —
riders differ a lot in how hard they actually go on a race climb — but
the *ordering* of a pen is more robust than any single time.

## 6. Predict the pen

Run every entrant through both sources of power numbers, with the
calibrated *k*:

``` r

preds <- field |>
  mutate(
    zr_min   = mapply(predict_climb, zr_wkg5, zr_wkg20, k = k) / 60,
    zp_min   = mapply(predict_climb, zp_wkg5, zp_wkg20, k = k) / 60,
    best_min = coalesce(zr_min, zp_min)
  ) |>
  arrange(best_min)

preds |>
  select(rider, team, zr_wkg20, zr_min, zp_min) |>
  mutate(across(where(is.numeric), \(x) round(x, 1))) |>
  print(n = Inf)
```

How well do the two sources agree?

``` r

with(preds, cor(zr_min, zp_min, use = "complete.obs"))

ggplot(preds, aes(zp_min, zr_min)) +
  geom_abline(linetype = 2, colour = "grey50") +
  geom_point(na.rm = TRUE) +
  labs(x = "Predicted from ZwiftPower sign-up numbers (min)",
       y = "Predicted from ZwiftRacing curve (min)") +
  theme_minimal()
```

Finally, put the pen in context: where would each entrant’s predicted
time sit among the reference team’s efforts on this climb over the last
year?

``` r

team_name <- zp_segment_standings(zp, segment_id, team_id) |> pull(tname) |> first()

ggplot() +
  geom_histogram(aes(elapsed / 60), binwidth = 1, fill = "grey80",
                 data = filter(team_efforts, when > Sys.time() - 365 * 86400)) +
  geom_rug(aes(best_min, colour = coalesce(team == team_name, FALSE)), data = preds,
           linewidth = 1, length = unit(0.08, "npc"), na.rm = TRUE) +
  scale_colour_manual(values = c(`TRUE` = "firebrick", `FALSE` = "steelblue"),
                      labels = c(`TRUE` = team_name, `FALSE` = "Other entrants"),
                      name = sprintf("Pen %s (predicted)", pen)) +
  labs(x = "Time up the climb (min)",
       y = sprintf("%s efforts, last 12 months", team_name)) +
  theme_minimal()
```

## Caveats

- **Extrapolation.** The CP model is fitted to 5- and 20-minute points
  and asked about 20–35 minutes. It tends to be optimistic far beyond 20
  minutes; the race-day fraction *k* absorbs some of that.
- **Race-day ≠ best.** *k* is a median: pacing, tactics, drafting and
  fatigue from the rest of the race vary a lot between riders, which is
  why individual errors are several minutes.
- **Calibration size.** *k* comes from one team’s efforts in the last
  year (a couple of dozen); efforts older than that are excluded because
  today’s power curve no longer describes the rider who set them.
- **One climb model.** The time–w/kg line is learned from one team’s
  efforts in races (some drafted, some solo). A different team gives a
  slightly different line.
- **Coverage.** Riders without a ZwiftRacing curve fall back to
  ZwiftPower’s sign-up numbers; riders with neither can’t be predicted.
  Riders who are on Zwift’s entrant list but haven’t signed up on
  ZwiftPower have no team. GDPR opt-outs simply don’t appear.
