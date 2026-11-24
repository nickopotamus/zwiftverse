# Authenticate against the Zwift game API

Performs an OAuth2 password-grant login and returns a handle that
refreshes the access token automatically. Requires your own Zwift
credentials.

## Usage

``` r
zwift_auth(
  username = Sys.getenv("ZWIFT_USERNAME"),
  password = Sys.getenv("ZWIFT_PASSWORD")
)
```

## Arguments

- username, password:

  Zwift account credentials. Default to the environment variables
  `ZWIFT_USERNAME` / `ZWIFT_PASSWORD`.

## Value

An object of class `zwift_auth`.

## Details

Token handling:

- Expiry times are measured from when the token *request was sent*, and
  a token is renewed early (10% of its lifetime, 5–60 s), so slow
  responses and modest clock skew don't produce expired tokens.

- When the access token expires the refresh token is used; if Zwift
  rejects the refresh (expired or revoked server-side), the handle logs
  in again with the password instead of failing.

- A `refresh_expires_in` of `0` (a Keycloak offline token) never
  expires.

- If the API answers `401` to a token the handle still thought valid,
  [`zwift_get()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_get.md)
  /
  [`zwift_post()`](https://nickopotamus.github.io/zwiftverse/reference/zwift_post.md)
  discard it and retry the request once.

The handle exposes `token()`, `login()`, `refresh()` and `invalidate()`;
printing it shows token status only, never the token or credentials.
