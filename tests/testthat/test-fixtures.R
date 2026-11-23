# Shape tests against recorded real payloads. The field names asserted here are
# the "inferred" assumptions from HANDOFF.md (Risks 1-3); a failure means the
# real API disagrees and the code/vignette must be updated to match.

# ---- ZwiftRacing.app ---------------------------------------------------------

test_that("ZR rider: one row, id field is riderId (Risk 3)", {
  use_fixture("zr", "rider")
  out <- zr_rider(fake_zr(), fixture_ids()$rider_id)
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1)
  expect_true("riderId" %in% names(out))
})

test_that("ZR rider: ratings nest under race$current/max30/max90 (Risk 2)", {
  use_fixture("zr", "rider")
  j <- zr_rider(fake_zr(), fixture_ids()$rider_id, parse = "json")
  expect_true(is.list(j$race))
  expect_true(all(c("current", "max30", "max90") %in% names(j$race)))
  expect_false(is.null(j$race$current$rating))
  expect_false(is.null(j$race$current$mixed$category))
})

test_that("ZR riders (batch POST): one row per rider, riderId present", {
  use_fixture("zr", "riders")
  out <- zr_riders(fake_zr(), fixture_ids()$rider_id)
  expect_s3_class(out, "tbl_df")
  expect_gte(nrow(out), 1)
  expect_true("riderId" %in% names(out))
})

for (ep in c("result", "club", "categories")) local({
  ep <- ep
  test_that(sprintf("ZR %s parses to a tibble", ep), {
    use_fixture("zr", ep)
    f <- switch(ep,
      result     = function() zr_result(fake_zr(), 1),
      club       = function() zr_club(fake_zr(), 1),
      categories = function() zr_categories(fake_zr()))
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
