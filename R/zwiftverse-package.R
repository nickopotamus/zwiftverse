#' @keywords internal
#' @import httr2
#' @importFrom tibble as_tibble tibble
#' @importFrom dplyr bind_rows
#' @importFrom rlang hash
"_PACKAGE"

# Internal infix: coalesce.
`%||%` <- function(a, b) if (is.null(a)) b else a
