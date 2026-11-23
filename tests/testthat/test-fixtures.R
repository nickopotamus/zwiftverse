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
