# Zwift service status

Reads Zwift's public status page (<https://status.zwift.com>). No login
needed. Use it to check whether a failed or odd-looking request is down
to a Zwift outage.

## Usage

``` r
zwift_status(
  what = c("status", "components", "unresolved", "incidents", "maintenance"),
  parse = "tbl",
  ttl = 60
)
```

## Arguments

- what:

  Which part of the status page:

  - `"status"` — one row: overall `indicator` (`none`, `minor`, `major`,
    `critical`) and `description` (e.g. "All Systems Operational");

  - `"components"` — one row per service (game servers, login, Companion
    app, ...) with its `status`;

  - `"unresolved"` — incidents still open (often zero rows);

  - `"incidents"` — the 50 most recent incidents;

  - `"maintenance"` — upcoming scheduled maintenance.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

- ttl:

  Cache time-to-live in seconds. Defaults to 60: status changes quickly.

## Value

A tibble (zero rows when there is nothing to report), parsed list, or
httr2 response.

## Examples

``` r
if (FALSE) { # \dontrun{
zwift_status()                    # overall indicator
zwift_status("components")        # per-service status
zwift_status("unresolved")        # anything broken right now?
} # }
```
