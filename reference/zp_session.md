# Create a ZwiftPower session

Create a ZwiftPower session

## Usage

``` r
zp_session(cookie_file = tempfile(fileext = ".cookies"), sid = NULL)
```

## Arguments

- cookie_file:

  Path to an on-disk cookie jar (used by [`zp_login()`](zp_login.md)).

- sid:

  Optional `phpbb3_lswlk_sid` value (see
  [`zp_set_cookie()`](zp_set_cookie.md)).

## Value

An object of class `zp_session`.
