# Zwift service status (status.zwift.com, a public Statuspage.io API).
# No authentication. Base: https://status.zwift.com/api/v2

.ZWIFT_STATUS_BASE <- "https://status.zwift.com/api/v2"

.ZWIFT_STATUS <- list(
  status      = c(path = "/status.json",                         key = "status"),
  components  = c(path = "/components.json",                     key = "components"),
  unresolved  = c(path = "/incidents/unresolved.json",           key = "incidents"),
  incidents   = c(path = "/incidents.json",                      key = "incidents"),
  maintenance = c(path = "/scheduled-maintenances/upcoming.json", key = "scheduled_maintenances")
)

#' Zwift service status
#'
#' Reads Zwift's public status page (<https://status.zwift.com>). No login
#' needed. Use it to check whether a failed or odd-looking request is down to
#' a Zwift outage.
#'
#' @param what Which part of the status page:
#'   * `"status"` — one row: overall `indicator` (`none`, `minor`, `major`,
#'     `critical`) and `description` (e.g. "All Systems Operational");
#'   * `"components"` — one row per service (game servers, login, Companion
#'     app, ...) with its `status`;
#'   * `"unresolved"` — incidents still open (often zero rows);
#'   * `"incidents"` — the 50 most recent incidents;
#'   * `"maintenance"` — upcoming scheduled maintenance.
#' @param parse One of `"tbl"`, `"json"`, `"resp"`.
#' @param ttl Cache time-to-live in seconds. Defaults to 60: status changes
#'   quickly.
#' @return A tibble (zero rows when there is nothing to report), parsed list,
#'   or httr2 response.
#' @export
#' @examples
#' \dontrun{
#' zwift_status()                    # overall indicator
#' zwift_status("components")        # per-service status
#' zwift_status("unresolved")        # anything broken right now?
#' }
zwift_status <- function(what = c("status", "components", "unresolved", "incidents",
                                  "maintenance"),
                         parse = "tbl", ttl = 60) {
  what <- match.arg(what)
  spec <- .ZWIFT_STATUS[[what]]
  req <- request(paste0(.ZWIFT_STATUS_BASE, spec[["path"]])) |>
    req_user_agent("zwiftverse (https://github.com/nickopotamus/zwiftverse)") |>
    req_retry(max_tries = 3) |>
    req_error(body = .zv_err_body)
  if (parse != "tbl") return(.zv_fetch(req, parse, ttl))
  j <- .zv_fetch(req, "json", ttl)
  out <- j[[spec[["key"]]]]
  if (!length(out)) return(tibble::tibble())
  .zv_to_tbl(out)
}
