# Create a ZwiftRacing.app client

Create a ZwiftRacing.app client

## Usage

``` r
zr_client(
  auth = Sys.getenv("ZR_AUTH"),
  key_type = c("user", "service"),
  rate = 2
)
```

## Arguments

- auth:

  Your ZwiftRacing.app API key. Defaults to the environment variable
  `ZR_AUTH`.

- key_type:

  `"user"` (default) for the per-account key from ZwiftRacing.app
  Settings -\> API access, sent as `Authorization` to the public routes;
  or `"service"` for a shared service key, sent as `x-api-key` to the
  website's v2 routes (what this package used before November 2026).

- rate:

  Throttle for `"service"` keys, in requests per second (default 2).
  User keys are throttled per route to the limits the server reports.

## Value

An object of class `zr_client`.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()                         # user key from ZR_AUTH
zr <- zr_client(Sys.getenv("ZR_SERVICE_KEY"), key_type = "service")
} # }
```
