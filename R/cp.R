# Critical power (CP) and W' --------------------------------------------------
# Cross-API helpers: ZwiftRacing.app publishes each rider's modelled CP and W'
# (`power.CP`, `power.AWC`) only inside event results, so the latest values come
# from the rider's most recent result. Failing that, fit the two-parameter CP
# model to ZwiftPower's 90-day power curve.

#' A rider's power curve from ZwiftPower
#'
#' The best-power curve behind a ZwiftPower profile page (`api3.php?do=
#' critical_power_profile`): best average watts for durations from 1 s to about
#' an hour, over a rolling window, with the date and event of each best.
#'
#' @param s A [zp_session()].
#' @param zwift_id Zwift rider id.
#' @param window `"90days"` (default), `"30days"`, or an event id for that
#'   event's curve.
#' @param parse `"tbl"`, `"json"` or `"resp"`.
#' @param ttl Cache time-to-live in seconds.
#' @return A tibble with one row per duration: `secs`, `watts`, `date`
#'   (POSIXct of the effort) and `event_id`. Zero rows when ZwiftPower holds no
#'   curve for the rider or window.
#' @export
#' @examples
#' \dontrun{
#' zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
#' zp_power_curve(zp, 1234567)
#' zp_power_curve(zp, 1234567, window = "30days")
#' }
zp_power_curve <- function(s, zwift_id, window = "90days", parse = "tbl",
                           ttl = .zv_ttl("zp")) {
  url <- sprintf("/api3.php?do=critical_power_profile&zwift_id=%s&zwift_event_id=&type=watts",
                 zwift_id)
  j <- zp_get(s, url, parse = if (parse == "tbl") "json" else parse, ttl = ttl)
  if (parse != "tbl") return(j)
  e <- if (is.list(j$efforts)) j$efforts[[as.character(window)]] else NULL
  if (!NROW(e) || is.null(e$x) || is.null(e$y)) {
    return(tibble::tibble(secs = numeric(), watts = numeric(),
                          date = as.POSIXct(numeric(), origin = "1970-01-01"),
                          event_id = character()))
  }
  tibble::tibble(secs = as.numeric(e$x), watts = as.numeric(e$y),
                 date = as.POSIXct(as.numeric(e$date %||% NA), origin = "1970-01-01"),
                 event_id = as.character(e$zid %||% NA))
}

#' A rider's critical power and W'
#'
#' Looks up a rider's most recent critical power (CP, W) and W' (J) as modelled
#' by ZwiftRacing.app, or estimates them from ZwiftPower's 90-day power curve
#' when ZwiftRacing has nothing recent enough.
#'
#' **ZwiftRacing.app.** CP and W' are only published inside event results, as
#' each rider's `power.CP` and `power.AWC` at the time of the event. The
#' function finds the rider's races from the last `max_age_days` and reads
#' their row from the newest event that has them (trying up to `tries`
#' events). A service key lists those races from ZwiftRacing; a user (Hobby)
#' key has no such route, so they come from the rider's ZwiftPower race
#' history, and `zp` is needed for this step too. If the key has no allowance
#' for event results, the function warns (now and then, not for every rider)
#' and uses the ZwiftPower fit.
#'
#' **ZwiftPower fallback.** If ZwiftRacing has no result within
#' `max_age_days`, or `zr` is `NULL`, the two-parameter model
#' `P(t) = CP + W'/t` is fitted to the 90-day curve from [zp_power_curve()] by
#' linear regression of work on time (`P*t = W' + CP*t`) over the `durations`
#' range (default 2-20 minutes). The fit is only as good as the efforts behind
#' the curve: a rider who has not gone full gas for 2 and 20 minutes lately
#' will get a low CP and an unreliable W'.
#'
#' A rider or event the API doesn't know (HTTP 404) just moves on to the next
#' source. Any other error, such as a rejected key, is raised.
#'
#' @param zr A [zr_client()], or `NULL` to skip ZwiftRacing.app.
#' @param zp A [zp_session()], or `NULL` to skip the ZwiftPower fallback.
#' @param zwift_id Zwift rider id.
#' @param max_age_days ZwiftRacing values older than this are ignored. At most
#'   365.
#' @param durations Range of durations (seconds) used for the ZwiftPower fit.
#' @param tries How many of the rider's most recent ZwiftRacing events to try.
#' @return A one-row tibble: `zwid`, `cp` (W), `w_prime` (J), `source`
#'   (`"zwiftracing"`, `"zwiftpower_fit"`, or `NA` if neither worked),
#'   `as_of` (POSIXct: the event, or the newest effort in the fit), `age_days`,
#'   `event_id` (the ZwiftRacing event the values come from) and `fit_r2` (R² of
#'   the ZwiftPower fit; `NA` for ZwiftRacing values).
#' @seealso [zv_signups_cp()] for every rider signed up to a race.
#' @export
#' @examples
#' \dontrun{
#' zr <- zr_client()
#' zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
#' zv_rider_cp(zr, zp, 1234567)
#' zv_rider_cp(NULL, zp, 1234567)        # ZwiftPower fit only
#' }
zv_rider_cp <- function(zr, zp, zwift_id, max_age_days = 90,
                        durations = c(120, 1200), tries = 3) {
  if (is.null(zr) && is.null(zp)) rlang::abort("Supply `zr`, `zp`, or both.")
  if (!is.null(zr)) stopifnot(inherits(zr, "zr_client"))
  if (!is.null(zp)) stopifnot(inherits(zp, "zp_session"))
  if (max_age_days > 365) {
    rlang::warn("ZwiftRacing.app serves at most 365 days of results; using 365.")
    max_age_days <- 365
  }
  zwift_id <- as.integer(zwift_id)
  now <- .zv_now()

  out <- if (!is.null(zr)) .zv_cp_from_zr(zr, zwift_id, max_age_days, tries, now, zp)
  zr_blocked <- isTRUE(attr(out, "zr_blocked"))
  if (!length(out)) out <- NULL
  if (is.null(out) && !is.null(zp)) out <- .zv_cp_from_zp(zp, zwift_id, durations)
  if (is.null(out)) out <- list(cp = NA_real_, w_prime = NA_real_, source = NA_character_,
                                as_of = NA_real_, event_id = NA_character_, fit_r2 = NA_real_)

  as_of <- as.POSIXct(as.numeric(out$as_of), origin = "1970-01-01")
  res <- tibble::tibble(zwid = zwift_id, cp = out$cp, w_prime = out$w_prime, source = out$source,
                        as_of = as_of,
                        age_days = as.numeric(difftime(now, as_of, units = "days")),
                        event_id = out$event_id, fit_r2 = out$fit_r2)
  if (zr_blocked) attr(res, "zr_blocked") <- TRUE    # lets zv_signups_cp() stop asking
  res
}

# Seam for tests: "now" for age calculations.
.zv_now <- function() Sys.time()

# A rider or event the API doesn't know (404) means "no data here, try the next
# source"; anything else (bad key, rate limit, outage) is a real error.
.zv_unless_404 <- function(expr) {
  tryCatch(expr, httr2_http_404 = function(e) NULL)
}

.zv_is_auth_error <- function(e) inherits(e, c("httr2_http_401", "httr2_http_403"))

.zv_cp_from_zr <- function(zr, zwift_id, max_age_days, tries, now, zp = NULL) {
  events <- .zv_recent_events(zr, zp, zwift_id, max_age_days, now)
  for (i in seq_len(min(tries, NROW(events)))) {
    ev <- tryCatch(.zv_unless_404(zr_result(zr, events$event_id[i])),
                   zv_zr_no_access = function(e) e)
    if (inherits(ev, "zv_zr_no_access")) {
      rlang::warn(c("Your ZwiftRacing.app key can't read event results, so CP and W' come from the ZwiftPower fit.",
                    i = conditionMessage(ev)),
                  .frequency = "regularly", .frequency_id = "zv_zr_results_no_access")
      return(structure(list(), zr_blocked = TRUE))
    }
    got <- .zv_cp_in_result(ev, zwift_id)
    if (is.null(got)) next
    return(c(got, list(source = "zwiftracing", as_of = events$time[i],
                       event_id = events$event_id[i], fit_r2 = NA_real_)))
  }
  NULL
}

# The rider's races within max_age_days, newest first (event_id, time).
# A service key lists them from ZwiftRacing; a user key has no such route, so
# they come from the rider's ZwiftPower race history.
.zv_recent_events <- function(zr, zp, zwift_id, max_age_days, now) {
  empty <- tibble::tibble(event_id = character(), time = numeric())
  cutoff <- as.numeric(now) - max_age_days * 86400
  ev <- if (.zr_is_service(zr)) {
    days <- if (max_age_days <= 90) 90 else 365       # the API rejects other windows
    res <- .zv_unless_404(zr_rider_results(zr, zwift_id, days = days))
    if (!NROW(res) || !all(c("event.eventId", "event.time") %in% names(res))) return(empty)
    tibble::tibble(event_id = as.character(res$event.eventId), time = as.numeric(res$event.time))
  } else {
    if (is.null(zp)) return(empty)
    prof <- .zv_unless_404(zp_profile(zp, zwift_id))
    if (!NROW(prof) || !all(c("zid", "event_date") %in% names(prof))) return(empty)
    prof <- zp_unflag(prof[, c("zid", "event_date")])
    tibble::tibble(event_id = as.character(prof$zid), time = suppressWarnings(as.numeric(prof$event_date)))
  }
  ev <- ev[!is.na(ev$time) & ev$time >= cutoff & ev$time <= as.numeric(now), , drop = FALSE]
  ev <- ev[!duplicated(ev$event_id), , drop = FALSE]
  ev[order(-ev$time), , drop = FALSE]
}

# Pull the rider's CP and W' out of an event's results. The v2 results call
# them power.CP / power.AWC; match those names wherever they sit.
.zv_cp_in_result <- function(ev, zwift_id) {
  if (!NROW(ev)) return(NULL)
  id_col <- intersect(c("riderId", "zwid", "zwiftId", "rider.riderId"), names(ev))[1]
  cp_col <- grep("(^|\\.)CP$", names(ev), value = TRUE)[1]
  wp_col <- grep("(^|\\.)AWC$", names(ev), value = TRUE)[1]
  if (is.na(id_col) || is.na(cp_col) || is.na(wp_col)) return(NULL)
  me <- ev[suppressWarnings(as.integer(ev[[id_col]])) %in% zwift_id, , drop = FALSE]
  if (!NROW(me)) return(NULL)
  cp <- suppressWarnings(as.numeric(me[[cp_col]][1]))
  wp <- suppressWarnings(as.numeric(me[[wp_col]][1]))
  if (is.na(cp) || is.na(wp) || cp <= 0 || wp <= 0) return(NULL)
  list(cp = cp, w_prime = wp)
}

.zv_cp_from_zp <- function(zp, zwift_id, durations) {
  curve <- .zv_unless_404(zp_power_curve(zp, zwift_id, window = "90days"))
  if (!NROW(curve)) return(NULL)
  fit <- .zv_cp_fit(curve$secs, curve$watts, durations)
  if (is.null(fit)) return(NULL)
  used <- curve$secs >= min(durations) & curve$secs <= max(durations)
  as_of <- suppressWarnings(max(as.numeric(curve$date[used]), na.rm = TRUE))
  list(cp = fit$cp, w_prime = fit$w_prime, source = "zwiftpower_fit",
       as_of = if (is.finite(as_of)) as_of else NA_real_,
       event_id = NA_character_, fit_r2 = fit$r2)
}

# Two-parameter CP model by linear regression of work on time:
#   P*t = W' + CP*t   (slope = CP, intercept = W')
# Returns NULL when there are fewer than 3 usable points or the fit is not
# physical (CP or W' <= 0).
.zv_cp_fit <- function(secs, watts, durations = c(120, 1200)) {
  ok <- !is.na(secs) & !is.na(watts) & watts > 0 &
    secs >= min(durations) & secs <= max(durations)
  secs <- secs[ok]; watts <- watts[ok]
  if (length(unique(secs)) < 3) return(NULL)
  work <- watts * secs
  m <- stats::lm(work ~ secs)
  cf <- stats::coef(m)
  cp <- unname(cf[["secs"]]); wp <- unname(cf[["(Intercept)"]])
  if (!is.finite(cp) || !is.finite(wp) || cp <= 0 || wp <= 0) return(NULL)
  # R² on power (not work), which is the scale people read the curve on.
  pred <- cp + wp / secs
  r2 <- 1 - sum((watts - pred)^2) / sum((watts - mean(watts))^2)
  list(cp = cp, w_prime = wp, r2 = r2)
}

#' Critical power and W' for everyone signed up to a race
#'
#' Runs [zv_rider_cp()] for every rider on a race's ZwiftPower sign-up list,
#' optionally one pen only.
#'
#' Each rider can cost a ZwiftPower race-history request, up to `tries`
#' ZwiftRacing.app results requests and a ZwiftPower power-curve request. All
#' are cached. ZwiftRacing allows a user key at most one results request a
#' minute, so with `zr` a large field can take a long time the first time; pass
#' `zr = NULL` for a quick ZwiftPower-only table. If the key has no results
#' allowance at all, ZwiftRacing is dropped after the first rider.
#'
#' @param zr A [zr_client()], or `NULL` to use only the ZwiftPower fit.
#' @param zp A [zp_session()] (required: the sign-ups come from ZwiftPower).
#' @param race_id ZwiftPower (= Zwift) event id.
#' @param pen Optional pen letter(s), e.g. `"C"`.
#' @param ... Passed to [zv_rider_cp()] (`max_age_days`, `durations`, `tries`).
#' @param progress Show a progress bar.
#' @return A tibble with one row per signed-up rider: `zwid`, `name`, `team`,
#'   `pen`, `weight` (kg, from the sign-up), the columns of [zv_rider_cp()],
#'   plus `cp_wkg` and `w_prime_jkg`.
#' @export
#' @examples
#' \dontrun{
#' zr <- zr_client()
#' zp <- zp_set_cookie(zp_session(), Sys.getenv("ZP_SID"))
#' field <- zv_signups_cp(zr, zp, 5812345, pen = "C")
#' dplyr::arrange(field, dplyr::desc(cp_wkg))
#' }
zv_signups_cp <- function(zr, zp, race_id, pen = NULL, ..., progress = interactive()) {
  stopifnot(inherits(zp, "zp_session"))
  su <- zp_unflag(zp_signups(zp, race_id))
  if (!NROW(su) || !"zwid" %in% names(su)) rlang::abort(sprintf("No sign-ups found for race %s.", race_id))

  riders <- tibble::tibble(
    zwid   = as.integer(su$zwid),
    name   = as.character(su$name %||% NA),
    team   = as.character(su$tname %||% NA),
    pen    = .zp_pen_letter(su$label %||% NA),
    weight = suppressWarnings(as.numeric(su$weight %||% NA))
  )
  riders$team[!nzchar(riders$team)] <- NA_character_
  riders$weight[!is.na(riders$weight) & riders$weight <= 0] <- NA_real_
  if (!is.null(pen)) riders <- riders[riders$pen %in% toupper(pen), ]
  riders <- riders[!duplicated(riders$zwid), ]
  if (!nrow(riders)) rlang::abort("No signed-up riders match `pen`.")

  if (progress) {
    pb <- utils::txtProgressBar(max = nrow(riders), style = 3)
    on.exit(close(pb), add = TRUE)
  }
  rows <- vector("list", nrow(riders))
  for (i in seq_len(nrow(riders))) {
    if (progress) utils::setTxtProgressBar(pb, i)
    rows[[i]] <- tryCatch(zv_rider_cp(zr, zp, riders$zwid[i], ...), error = function(e) {
      if (.zv_is_auth_error(e)) {
        rlang::abort(c("Authentication failed, so stopping.",
                       i = "Check ZR_AUTH / ZP_SID, or pass `zr = NULL` to use only ZwiftPower."),
                     parent = e)
      }
      rlang::warn(sprintf("Rider %s: %s", riders$zwid[i], conditionMessage(e)))
      NULL
    })
    if (isTRUE(attr(rows[[i]], "zr_blocked"))) zr <- NULL    # no point asking again
  }
  cp <- dplyr::bind_rows(rows)
  out <- dplyr::left_join(riders, cp, by = "zwid")
  out$cp_wkg <- out$cp / out$weight
  out$w_prime_jkg <- out$w_prime / out$weight
  out
}

# ZwiftPower sign-up `label`: 1-5 = A-E (0 / other = unknown).
.zp_pen_letter <- function(label) {
  l <- suppressWarnings(as.integer(label))
  out <- rep(NA_character_, length(l))
  ok <- !is.na(l) & l >= 1 & l <= 5
  out[ok] <- LETTERS[l[ok]]
  out
}
