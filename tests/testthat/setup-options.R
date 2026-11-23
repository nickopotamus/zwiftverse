# Runs once before the test suite (not on load_all()); restored afterwards.
old_opts <- options(zwiftverse.cache = FALSE)
withr::defer(options(old_opts), teardown_env())
