# Log in to ZwiftPower via Zwift SSO (best effort)

Scrapes the Keycloak login form and submits your Zwift credentials. This
is brittle - if the SSO flow changes it will fail; use
[`zp_set_cookie()`](zp_set_cookie.md) instead. Requires the suggested
packages rvest and xml2.

## Usage

``` r
zp_login(
  s,
  username = Sys.getenv("ZWIFT_USERNAME"),
  password = Sys.getenv("ZWIFT_PASSWORD")
)
```

## Arguments

- s:

  A [`zp_session()`](zp_session.md).

- username, password:

  Zwift credentials (default to env vars).

## Value

Invisibly, the session.
