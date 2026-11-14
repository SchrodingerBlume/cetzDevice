.backend <- list(cetz = "0.5.3", typst_min = "0.15.0")

#' Inspect the Target CeTZ and Typst Versions
#'
#' The first three package version components identify the exact CeTZ version;
#' the fourth counts device releases for that version.
#' @return A list with the pinned cetz version and minimum typst_min version.
#' @export
cetz_backend <- function() .backend

.cetz_import <- function() paste0('#import "@preview/cetz:', .backend$cetz, '" as cetz')

.require_typst <- function(version) {
  text <- paste(version, collapse = " ")
  found <- regmatches(text, regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", text))
  if (!length(found) || !nzchar(found) ||
      numeric_version(found) < numeric_version(.backend$typst_min))
    stop("CeTZ ", .backend$cetz, " requires Typst >= ", .backend$typst_min,
         "; found ", text, call. = FALSE)
  invisible(NULL)
}
