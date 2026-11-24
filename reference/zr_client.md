# Create a ZwiftRacing.app client

Create a ZwiftRacing.app client

## Usage

``` r
zr_client(auth = Sys.getenv("ZR_AUTH"), rate = 2)
```

## Arguments

- auth:

  Your ZwiftRacing.app API key, sent as the `x-api-key` header. Defaults
  to the environment variable `ZR_AUTH`.

- rate:

  Throttle in requests per second (default 2; tune to your quota).

## Value

An object of class `zr_client`.

## Examples

``` r
if (FALSE) { # \dontrun{
zr <- zr_client()                  # key from the ZR_AUTH environment variable
zr <- zr_client("your-key", rate = 1)
} # }
```
