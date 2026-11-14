# Encode labels as strings; the graphics engine discards S3 attributes.
.label_token <- function(x, mode) {
  if (!is.character(x) || anyNA(x)) stop("Labels must be non-missing strings", call. = FALSE)
  vapply(enc2utf8(x), function(value) {
    paste0("__cetz_", mode, "__:", gsub("\n", "", jsonlite::base64_enc(charToRaw(value)), fixed = TRUE))
  }, character(1L), USE.NAMES = FALSE)
}

#' Mark labels as native Typst markup
#' @param x Character vector of markup labels.
#' @return Character vector for use in R plot labels.
#' @export
cetz_typst <- function(x) .label_token(x, "typst")

#' Mark labels as LaTeX text interpreted by MiTeX
#' @param x Character vector of LaTeX labels; use dollar delimiters for mathematics.
#' @return Character vector for use in R plot labels.
#' @export
cetz_latex <- function(x) .label_token(x, "latex")

.resolve_label <- function(string, state, plain = FALSE) {
  if (plain) return(list(value = string, mode = "plain"))
  mode <- state$text_mode
  for (candidate in c("typst", "latex")) {
    prefix <- paste0("__cetz_", candidate, "__:")
    if (startsWith(string, prefix)) {
      string <- tryCatch(rawToChar(jsonlite::base64_dec(substring(string, nchar(prefix) + 1L))),
                         error = function(e) stop("Invalid cetzDevice label token", call. = FALSE))
      mode <- candidate
      break
    }
  }
  if (mode == "latex") state$needs_mitex <- TRUE
  list(value = string, mode = mode)
}

.typst_header <- function(state) {
  c(if (isTRUE(state$needs_mitex))
      '#import "@preview/mitex:0.2.6": mitext as r-mitext',
    "#let r-label-scope = (:)", state$preamble)
}
