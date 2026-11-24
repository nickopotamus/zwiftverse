# Shape tests against recorded real payloads. The field names asserted here were
# verified against live responses (HANDOFF.md Risks 1-3); a failure means the
# upstream API has changed and the code/vignette must be updated to m# ---- ZwiftRacing.app (v2) ----------------------------------------------------

test_that("ZR rider: envelope unwrapped to one row; riderId present (Risk 3)", {
  use_fixture("zr", "rider")
  out <- zr_rider(fake_zr(), fixture_ids()$rider_id)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true(all(c("riderId", "velo", "race", "power", "club") %in% names(out)))
})

test_that("ZR rider: v2 rating lives at velo$race; race holds counts (Risk 2)", {
  use_fixture("zr", "rider")
  j <- zr_rider(fake_zr(), fixture_ids()$rider_id, parse = "json")
  expect_true(isTRUE(j$success))
  expect_type(j$data$velo$race, "double")
  expect_true(all(c("endurance", "sprint", "climb") %in% names(j$data$velo$factors)))
  expect_true(all(c("finishes", "wins", "podiums", "dnfs") %in% names(j$data$race)))
})

test_that("ZR rider overview exposes legacy live/max30/max90 ratings", {
  use_fixture("zr", "rider_overview")
  j <- zr_rider_overview(fake_zr(), 1, parse = "json")
  expect_true(all(c("live", "max30", "max90") %in% names(j$data$legacyRatings)))
})

test_that("ZR rider results: one row per race, flattened nested fields", {
  use_fixture("zr", "rider_results")
  out <- zr_rider_results(fake_zr(), 1)
  expect_s3_class(out, "tbl_df")
  expect_gte(nrow(out), 1)
  expect_true(all(c("event.eventId", "place.positionInCategory", "legacy.ratingBefore") %in% names(out)))
})

test_that("ZR result: event pens flattened to one row per rider", {
  use_fixture("zr", "event")
  out <- zr_result(fake_zr(), 1)
  expect_s3_class(out, "tbl_df")
  expect_gt(nrow(out), 1)
  expect_true(all(c("pen", "riderId", "position", "category", "ratingBefore",
                    "rating", "riderVelo.race") %in% names(out)))
})

test_that("ZR riders: binds one row per rider", {
  use_fixture("zr", "rider")
  out <- zr_riders(fake_zr(), c(1, 2))
  expect_equal(nrow(out), 2)
  expect_true("riderId" %in% names(out))
})

test_that("ZR club riders: single page parses", {
  use_fixture("zr", "club_riders")
  out <- zr_club_riders(fake_zr(), 1, page = 0)
  expect_gt(nrow(out), 1)
  expect_true(all(c("riderId", "velo.race") %in% names(out)))
})

for (ep in c("rider_ranking", "rider_velo", "rider_power", "club", "routes")) local({
  ep <- ep
  test_that(sprintf("ZR %s parses to a tibble", ep), {
    use_fixture("zr", ep)
    f <- switch(ep,
      rider_ranking = function() zr_rider_ranking(fake_zr(), 1),
      rider_velo    = function() zr_rider_velo(fake_zr(), 1),
      rider_power   = function() zr_rider_power(fake_zr(), 1),
      club          = function() zr_club(fake_zr(), 1),
      routes        = function() zr_routes(fake_zr()))
    out <- f()
    expect_s3_class(out, "tbl_df")
    expect_gte(ncol(out), 1)
  })
})

# ---- ZwiftPower ---------------------------------------------------------------

test_that("ZP result: one row per finisher with the vignette's columns (Risk 1)", {
  use_fixture("zp", "result")
  out <- zp_result(fake_zp(), 1)
  expect_s3_class(out, "tbl_df")
  expect_gt(nrow(out), 1)
  expect_true(all(c("zwid", "position_in_cat", "category", "avg_wkg") %in% names(out)),
              info = paste("columns:", paste(names(out), collapse = ", ")))
})

test_that("ZP segment standings: one row per rider with time and w/kg", {
  use_fixture("zp", "segment_standings")
  out <- zp_unflag(zp_segment_standings(fake_zp(), 13, 1))
  expect_gt(nrow(out), 1)
  expect_true(all(c("zwid", "elapsed", "wkg", "power", "weight", "zid", "date") %in% names(out)))
  expect_true(all(as.numeric(out$elapsed) > 0))
})

test_that("ZP analysis: race-report streams to one row per sample", {
  use_fixture("zp", "analysis")
  out <- zp_analysis(fake_zp(), 1, 42)
  expect_gt(nrow(out), 1)
  expect_true(all(c("zwid", "time", "distance", "power", "heart_rate", "altitude") %in% names(out)))
  expect_true(all(out$zwid == 42L))
  expect_false(is.unsorted(out$time))
  expect_type(out$power, "double")
})

test_that("ZP analysis: a rider with no data (empty body) gives zero rows", {
  httr2::local_mocked_responses(function(req) httr2::response(status_code = 200, url = req$url))
  out <- zp_analysis(fake_zp(), 1, 42)
  expect_equal(nrow(out), 0)
  expect_true(all(c("zwid", "time", "distance") %in% names(out)))
})

test_that("ZP event analysis: one stream per finisher in the pen, with name + category", {
  use_fixture_routes("zp", c("do=analysis" = "analysis", "_view\\.json" = "result"))
  res <- zp_result(fake_zp(), 1)
  pen <- res$category[[1]]
  out <- zp_event_analysis(fake_zp(), 1, pen = pen, progress = FALSE)
  expect_equal(names(out)[1:3], c("zwid", "name", "category"))
  expect_true(all(out$category == pen))
  expect_setequal(unique(out$zwid), unique(as.integer(res$zwid[res$category == pen])))
  expect_error(zp_event_analysis(fake_zp(), 1, pen = "Z", progress = FALSE), "No riders")
})

for (ep in c("profile", "signups", "sprints", "primes", "team")) local({
  ep <- ep
  test_that(sprintf("ZP %s parses to a tibble", ep), {
    use_fixture("zp", ep)
    f <- switch(ep,
      profile = function() zp_profile(fake_zp(), 1),
      signups = function() zp_signups(fake_zp(), 1),
      sprints = function() zp_sprints(fake_zp(), 1),
      primes  = function() zp_primes(fake_zp(), 1),
      team    = function() zp_team(fake_zp(), 1))
    expect_s3_class(f(), "tbl_df")
  })
})

# ---- Zwift game API -----------------------------------------------------------

test_that("Zwift profile: one row with id", {
  use_fixture("zwift", "profile")
  out <- zwift_profile(fake_zwift())
  expect_equal(nrow(out), 1)
  expect_true("id" %in% names(out))
})

test_that("Zwift event subgroups: one row per pen with id + label", {
  use_fixture("zwift", "event")
  out <- zwift_event_subgroups(fake_zwift(), 1)
  expect_gte(nrow(out), 1)
  expect_true(all(c("id", "subgroupLabel") %in% names(out)))
})

test_that("Zwift subgroup results: entries unwrapped, ranked, nested fields flattened", {
  use_fixture("zwift", "subgroup_results")
  out <- zwift_subgroup_results(fake_zwift(), 1)
  expect_gt(nrow(out), 1)
  expect_true(all(c("rank", "profileId", "activityData.durationInMilliseconds",
                    "sensorData.avgWatts", "criticalP.criticalP20Minutes") %in% names(out)))
  expect_false(is.unsorted(out$rank))
})

test_that("Zwift event results: every subgroup bound with a subgroup column", {
  use_fixture_routes("zwift", c("race-results" = "subgroup_results", "/api/events/" = "event"))
  sg <- zwift_event_subgroups(fake_zwift(), 1)
  out <- zwift_event_results(fake_zwift(), 1)
  expect_equal(names(out)[1], "subgroup")
  expect_setequal(unique(out$subgroup), sg$subgroupLabel)
})

test_that("Zwift subgroup entrants parse to one row per rider", {
  use_fixture("zwift", "subgroup_entrants")
  out <- zwift_subgroup_entrants(fake_zwift(), 1)
  expect_gt(nrow(out), 1)
  expect_true("id" %in% names(out))
})

test_that("Zwift activities: limit above a page auto-pages; json refuses to", {
  use_fixture("zwift", "activities")
  expect_s3_class(zwift_activities(fake_zwift(), limit = 120), "tbl_df")
  expect_error(zwift_activities(fake_zwift(), limit = 120, parse = "json"), "parse")
})

for (ep in c("activities", "followees", "event", "worlds")) local({
  ep <- ep
  test_that(sprintf("Zwift %s parses to a tibble", ep), {
    use_fixture("zwift", ep)
    f <- switch(ep,
      activities = function() zwift_activities(fake_zwift()),
      followees  = function() zwift_followees(fake_zwift()),
      event      = function() zwift_event(fake_zwift(), 1),
      worlds     = function() zwift_worlds(fake_zwift()))
    expect_s3_class(f(), "tbl_df")
  })
})

test_that("zp_unflag turns [value, flag] list-columns into numbers", {
  use_fixture("zp", "result")
  out <- zp_unflag(zp_result(fake_zp(), 1))
  expect_type(out$avg_wkg, "double")
  expect_type(out$avg_power, "integer")
  expect_false(any(vapply(out[c("avg_wkg", "avg_power", "time")], is.list, logical(1))))
  expect_true(all(out$avg_wkg > 0 & out$avg_wkg < 10, na.rm = TRUE))
})

test_that("zp_unflag takes the value (element 2) from sign-up cp triples", {
  use_fixture("zp", "signups")
  raw <- zp_signups(fake_zp(), 1)
  out <- zp_unflag(raw)
  expect_type(out$cp_1200_wkg, "double")
  w <- vapply(raw$cp_1200_watts, function(v) as.numeric(v[[2]]), numeric(1))
  expect_equal(out$cp_1200_watts, w)
  expect_true(all(out$cp_1200_wkg > 0.5 & out$cp_1200_wkg < 8, na.rm = TRUE))
})
