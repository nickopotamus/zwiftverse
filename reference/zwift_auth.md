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
