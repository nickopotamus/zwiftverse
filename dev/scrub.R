# PII scrubber for recorded fixtures. Keeps the JSON *shape* and field names
# (which is what the tests pin) but replaces personal values:
#   * id-like fields (zwid, riderId, id, ...) -> consistent synthetic ids
#     (same real id -> same fake id across every fixture, so joins still work),
#     and any other occurrence of a mapped real id anywhere is rewritten too;
#   * names / emails / dob / photos / free text -> placeholders;
#   * body weight / height -> fixed plausible values (unit-aware).

.ZV_ID_KEYS   <- c("zwid", "riderid", "playerid", "profileid", "athleteid",
                   "userid", "id", "zwiftid", "zid", "uid")
.ZV_NAME_KEYS <- c("name", "firstname", "lastname", "fullname", "displayname",
                   "username", "nickname")
.ZV_PII_KEYS  <- c("email", "emailaddress", "dob", "dateofbirth", "birthdate",
                   "address", "phone", "imagesrc", "imagesrclarge", "avatar",
                   "avatarurl", "profileimage", "twitter", "strava", "stravaid",
                   "publicid", "description", "bio", "socialfacts",
                   "privateattributes", "mixpanel", "connectedtostrava",
                   "connectedtotrainingpeaks", "connectedtotodaysplan",
                   "connectedtounderarmour", "connectedtowithings",
                   "connectedtofitbit", "connectedtogarmin")
# Fixed placeholders, unit-aware: Zwift uses g / mm, ZR/ZP use kg / cm.
.zv_body <- function(k, v) {
  if (k == "weight") if (v > 500) 70000 else 70
  else if (v > 300) 1750 else 175
}

zv_scrub_new_map <- function() { e <- new.env(); e$map <- character(); e }

.zv_idlike <- function(v) {
  (is.numeric(v) && length(v) == 1 && !is.na(v) && v >= 1000 && v == floor(v)) ||
    (is.character(v) && length(v) == 1 && grepl("^[0-9]{4,}$", v))
}

.zv_fake_id <- function(real, m) {
  k <- as.character(real)
  if (!k %in% names(m$map)) m$map[[k]] <- as.character(1000000 + length(m$map) + 1)
  m$map[[k]]
}

.zv_same_type <- function(orig, fake) if (is.numeric(orig)) as.numeric(fake) else fake

# Pass 1: walk and replace by key.
.zv_scrub1 <- function(x, m, key = "") {
  k <- tolower(key)
  if (is.list(x)) {
    nm <- names(x)
    out <- lapply(seq_along(x), function(i) .zv_scrub1(x[[i]], m, if (is.null(nm)) key else nm[[i]]))
    names(out) <- nm
    return(out)
  }
  if (is.null(x) || length(x) != 1 || is.na(x)) return(x)
  if (k %in% .ZV_ID_KEYS && .zv_idlike(x)) return(.zv_same_type(x, .zv_fake_id(x, m)))
  if (k %in% .ZV_NAME_KEYS && is.character(x)) return("Test Rider")
  if (k %in% .ZV_PII_KEYS) return(if (is.character(x)) "REDACTED" else if (is.logical(x)) FALSE else 0)
  if (k %in% c("weight", "height") && is.numeric(x)) return(.zv_body(k, x))
  x
}

# Pass 2: any remaining scalar (or object key) equal to a mapped real id.
.zv_scrub2 <- function(x, m) {
  if (is.list(x)) {
    nm <- names(x)
    out <- lapply(x, .zv_scrub2, m = m)
    if (!is.null(nm)) names(out) <- ifelse(nm %in% names(m$map), m$map[nm], nm)
    return(out)
  }
  if (length(x) == 1 && !is.na(x) && .zv_idlike(x)) {
    k <- as.character(x)
    if (k %in% names(m$map)) return(.zv_same_type(x, m$map[[k]]))
  }
  x
}

zv_scrub_json <- function(txt, m) {
  x <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  x <- .zv_scrub2(.zv_scrub1(x, m), m)
  jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null",
                   pretty = TRUE, digits = NA)
}

# Seed the map with ids you know are real (e.g. the rider id you tested with),
# so pass 2 catches them even where they appear under an unexpected key.
zv_scrub_seed <- function(m, ids) { for (i in ids) if (!is.null(i)) .zv_fake_id(i, m); invisible(m) }
