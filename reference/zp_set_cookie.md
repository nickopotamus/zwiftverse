# Set the ZwiftPower session cookie directly

The robust alternative to
[`zp_login()`](https://nickopotamus.github.io/zwiftverse/reference/zp_login.md):
log in at zwiftpower.com in a browser, copy the `phpbb3_lswlk_sid`
cookie value from devtools, and pass it here.

## Usage

``` r
zp_set_cookie(s, sid)
```

## Arguments

- s:

  A
  [`zp_session()`](https://nickopotamus.github.io/zwiftverse/reference/zp_session.md).

- sid:

  The `phpbb3_lswlk_sid` cookie value.

## Value

The updated session.

## Examples

``` r
if (FALSE) { # \dontrun{
zp <- zp_set_cookie(zp_session(), "PASTE_phpbb3_lswlk_sid")
} # }
```
