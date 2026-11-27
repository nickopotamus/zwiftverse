# Pseudonymise riders in the pre-rendered vignettes. Sourced by a hidden chunk
# of each vignettes/*.Rmd.orig (see vignettes/precompute.R); not part of the
# package and not shipped (it is .Rbuildignore'd).
#
# The vignette code calls the package's API functions as a reader would. This
# file masks those functions in the knitting environment so that, at the API
# boundary:
#   * rider ids in results become fake 9-digit ids (100000001, ...), the same
#     fake id for the same rider everywhere, so joins still work;
#   * fake ids passed back into a later call are turned back into real ones;
#   * rider names become "Rider N" (N from the fake id), team / club names
#     become "Team A", "Team B", ...
# Event, segment and team ids are public and are left alone.

.anon <- new.env()
.anon$ids   <- character()   # names: real id; values: fake id
.anon$teams <- character()   # names: real team name; values: pseudonym
.anon$names <- character()   # real rider names seen (for the leak check)

.ANON_ID_COLS   <- c("zwid", "riderId", "zwift_id", "uid", "profileId", "playerId")
.ANON_NAME_COLS <- c("name", "fullName", "rider", "displayName")
.ANON_TEAM_COLS <- c("tname", "team", "club.name", "clubName", "tag")
.ANON_DROP_COLS <- c("imageSrc", "imageSrcLarge", "twitter",
                     "emailAddress", "dob", "publicId", "socialFacts", "privateAttributes")

.anon_id <- function(x) {
  k <- as.character(x)
  todo <- unique(k[!is.na(k) & nzchar(k) & !k %in% names(.anon$ids)])
  if (length(todo)) .anon$ids[todo] <- as.character(100000000L + length(.anon$ids) + seq_along(todo))
  out <- unname(.anon$ids[k])
  out[is.na(k) | !nzchar(k)] <- NA
  if (is.numeric(x)) as.numeric(out) else out
}

.anon_team <- function(x) {
  k <- trimws(as.character(x))
  todo <- unique(k[!is.na(k) & nzchar(k) & !k %in% names(.anon$teams)])
  if (length(todo)) {
    n <- length(.anon$teams) + seq_along(todo)
    .anon$teams[todo] <- paste("Team", ifelse(n <= 26, LETTERS[pmin(n, 26)], n))
  }
  out <- unname(.anon$teams[k])
  out[is.na(k) | !nzchar(k)] <- x[is.na(k) | !nzchar(k)]
  out
}

.anon_rider_name <- function(fake) ifelse(is.na(fake), NA, paste("Rider", as.numeric(fake) - 100000000))

# Fake ids back to real ones, for arguments passed into the API.
.anon_unfake <- function(x) {
  if (!(is.numeric(x) || is.character(x)) || !length(.anon$ids)) return(x)
  rev <- stats::setNames(names(.anon$ids), .anon$ids)
  k <- as.character(x)
  hit <- k %in% names(rev)
  if (!any(hit)) return(x)
  k[hit] <- rev[k[hit]]
  if (is.numeric(x)) as.numeric(k) else k
}

# Anonymise a tibble (or a list from parse = "json").
.anon_df <- function(d, id_cols = .ANON_ID_COLS) {
  if (is.data.frame(d)) {
    id_col <- intersect(id_cols, names(d))[1]
    for (col in intersect(id_cols, names(d))) d[[col]] <- .anon_id(d[[col]])
    for (col in intersect(.ANON_TEAM_COLS, names(d))) if (is.character(d[[col]])) d[[col]] <- .anon_team(d[[col]])
    for (col in intersect(c(.ANON_NAME_COLS, "firstName", "lastName"), names(d)))
      if (is.character(d[[col]])) .anon$names <- unique(c(.anon$names, d[[col]]))
    for (col in intersect(.ANON_NAME_COLS, names(d))) if (is.character(d[[col]]))
      d[[col]] <- if (!is.na(id_col)) .anon_rider_name(d[[id_col]]) else "Rider"
    # Zwift splits names: "Rider" + the number, so paste(firstName, lastName) works.
    if ("firstName" %in% names(d)) d$firstName <- ifelse(is.na(d$firstName), NA, "Rider")
    if ("lastName" %in% names(d))
      d$lastName <- if (!is.na(id_col)) as.character(as.numeric(d[[id_col]]) - 100000000) else ""
    d <- d[, setdiff(names(d), .ANON_DROP_COLS), drop = FALSE]
    # Nested personal objects (e.g. ZwiftRacing's club) are walked too.
    for (col in names(d)) if (is.data.frame(d[[col]])) d[[col]] <- .anon_df(d[[col]], character())
    return(d)
  }
  if (is.list(d)) {
    for (k in intersect(id_cols, names(d))) d[[k]] <- .anon_id(d[[k]])
    for (k in intersect(.ANON_TEAM_COLS, names(d))) if (is.character(d[[k]])) d[[k]] <- .anon_team(d[[k]])
    for (k in intersect(c(.ANON_NAME_COLS, "firstName", "lastName"), names(d)))
      if (is.character(d[[k]])) .anon$names <- unique(c(.anon$names, d[[k]]))
    for (k in intersect(.ANON_NAME_COLS, names(d))) if (is.character(d[[k]])) d[[k]] <- "Rider"
    if (!is.null(d$firstName)) d$firstName <- "Rider"
    if (!is.null(d$lastName)) d$lastName <- ""
    d[intersect(.ANON_DROP_COLS, names(d))] <- NULL
  }
  d
}

# Wrap a package function: unfake its arguments, anonymise its result.
.anon_wrap <- function(fn, id_cols = .ANON_ID_COLS) {
  f <- getExportedValue("zwiftverse", fn)
  function(...) {
    args <- lapply(list(...), .anon_unfake)
    out <- do.call(f, args)
    if (inherits(out, "httr2_response")) stop("anonymise.R: parse = \"resp\" is not supported")
    .anon_df(out, id_cols)
  }
}

# Functions whose results describe riders. Zwift's entrant list keys riders on `id`.
for (.fn in c("zp_result", "zp_signups", "zp_segment_standings", "zr_rider", "zr_riders",
              "zp_profile"))
  assign(.fn, .anon_wrap(.fn), envir = knitr::knit_global())
assign("zwift_subgroup_entrants", .anon_wrap("zwift_subgroup_entrants", c("id", .ANON_ID_COLS)),
       envir = knitr::knit_global())
assign("zwift_profile", .anon_wrap("zwift_profile", c("id", .ANON_ID_COLS)),
       envir = knitr::knit_global())
rm(.fn)

# Every real value that must not appear in the rendered output; checked by
# precompute.R after knitting.
.anon_leaks <- function() {
  x <- c(names(.anon$ids), names(.anon$teams), .anon$names)
  x <- trimws(x[!is.na(x)])
  unique(x[nchar(x) >= 4])   # very short strings would match ordinary text
}
