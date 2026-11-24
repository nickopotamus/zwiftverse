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

  Request body (encoded as JSON). Defaults to an empty object.

- parse:

  One of `"tbl"`, `"json"`, `"resp"`.
