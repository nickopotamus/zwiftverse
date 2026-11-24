# Low-level Zwift POST

Low-level Zwift POST

## Usage

``` r
zwift_post(auth, path, body = NULL, parse = "resp")
```

## Arguments

- auth:

  A
  [`zwift_auth()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_auth.md)
  handle.

- path:

  Endpoint path, e.g. `"/api/profiles/me"`.

- body:

  Request body (encoded as JSON). `NULL` (default) sends no body.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.

## Value

The httr2 response (or parsed JSON / tibble if `parse` says so).

## Examples

``` r
if (FALSE) { # \dontrun{
za <- zwift_auth()
# give a ride-on (what zwift_give_rideon() does)
zwift_post(za, "/api/profiles/1234567/activities/987654321/rideon",
           body = list())
} # }
```
