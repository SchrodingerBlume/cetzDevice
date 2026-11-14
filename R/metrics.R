.num <- function(x) {
  if (any(!is.finite(x))) stop("Non-finite drawing coordinate", call. = FALSE)
  x[abs(x) < 0.0000005] <- 0
  formatC(x, format = "f", digits = 6L, decimal.mark = ".", drop0trailing = TRUE)
}

.str <- function(x) {
  # jsonlite escapes HTML closing slashes; Typst does not decode JSON's \/.
  gsub("\\/", "/", as.character(jsonlite::toJSON(unname(enc2utf8(x)), auto_unbox = TRUE)), fixed = TRUE)
}

.font <- function(style, state) {
  family <- style$family
  if (is.null(family) || !nzchar(family)) family <- state$family
  if (style$face == 5L) family <- "symbol"
  if (family %in% names(state$font_map)) family <- unname(state$font_map[[family]])
  bold <- style$face %in% c(2L, 4L)
  italic <- style$face %in% c(3L, 4L)
  if (identical(state$metrics_backend, "systemfonts")) {
    key <- paste(family, bold, italic, sep = "\034")
    resolved <- state$resolved_fonts[[key]]
    if (is.null(resolved)) {
      info <- systemfonts::font_info(family = family, italic = italic,
        weight = if (bold) "bold" else "normal")
      resolved <- unname(info$family[1L])
      state$resolved_fonts[[key]] <- resolved
    }
    # Use the measured substitute font in the output.
    family <- resolved
  }
  list(family = family, bold = bold, italic = italic)
}

.text_expr <- function(string, style, state, colour = NULL, plain = FALSE) {
  font <- .font(style, state)
  label <- .resolve_label(string, state, plain)
  body <- switch(label$mode,
    plain = .str(label$value),
    typst = paste0("eval(", .str(label$value), ", mode: \"markup\", scope: r-label-scope)"),
    latex = paste0("r-mitext(", .str(label$value), ")"))
  paste0("text(font: ", .str(font$family), ", size: ", .num(style$size),
         "pt, weight: ", if (font$bold) '"bold"' else '"regular"',
         ", style: ", if (font$italic) '"italic"' else '"normal"',
         ", lang: \"en\", hyphenate: false, ligatures: false",
         if (!is.null(colour)) paste0(", fill: ", colour), ", ", body, ")")
}

.metric_backend <- function(state, backend, typst) {
  engine <- if (backend == "typst") .typst_version(typst) else
    as.character(utils::packageVersion("systemfonts"))
  if (backend == "typst") .require_typst(engine)
  configuration <- list(version = 3L, backend = backend, engine = engine,
    platform = R.version$platform,
    preamble = state$preamble, directory = if (length(state$preamble)) dirname(state$file),
    dependencies = .preamble_dependencies(state$preamble, dirname(state$file)),
    font_env = Sys.getenv(c("TYPST_FONT_PATHS", "TYPST_IGNORE_SYSTEM_FONTS", "TYPST_PACKAGE_PATH",
                           "TYPST_PACKAGE_CACHE_PATH")), cache_key = state$cache_key)
  function(string, style) {
    plain <- is.integer(string)
    if (plain) string <- intToUtf8(if (string == 0L) 77L else string)
    if (!nzchar(string)) return(c(0, 0, 0))
    font <- .font(style, state)
    label <- .resolve_label(string, state, plain)
    if (backend == "systemfonts" && label$mode != "plain")
      stop("Typst/MiTeX labels require metrics = 'typst'", call. = FALSE)
    expression <- .text_expr(string, style, state, plain = plain)
    key <- digest::digest(list(configuration, expression), algo = "sha256")
    cached <- .cache_get(key, state$cache_dir)
    if (!is.null(cached)) return(cached)
    .cache_stats$misses <- .cache_stats$misses + 1L
    if (backend == "systemfonts") {
      weight <- if (font$bold) "bold" else "normal"
      width <- systemfonts::string_width(string, family = font$family,
        italic = font$italic, weight = weight, size = style$size, res = 72)
      glyph <- systemfonts::glyph_info(string, family = font$family,
        italic = font$italic, weight = weight, size = style$size, res = 72)
      result <- c(width, max(glyph$y_bearing), max(glyph$height - glyph$y_bearing))
    } else {
      source <- state$metric_source
      errors <- file.path(state$temp, "stderr.txt")
      writeLines(c(
        "#set page(width: 10000pt, height: 10000pt, margin: 0pt)",
        .typst_header(state),
        "#context {",
        paste0("  let body = ", expression),
        "  let bounded = text(top-edge: \"bounds\", bottom-edge: \"bounds\", body)",
        "  let size = measure(bounded)",
        "  let p = size.height + 1pt",
        "  let up = box(width: 0pt, height: p, baseline: 0pt)",
        "  let down = box(width: 0pt, height: p, baseline: p)",
        "  let hu = measure(box[#box(bounded)#up]).height",
        "  let hd = measure(box[#box(bounded)#down]).height",
        "  let a = if hu - hd > size.height { p + size.height - hu } else { hd - p }",
        "  [#metadata((size.width / 1pt, a / 1pt, (size.height - a) / 1pt)) <r2cetz-metrics>]",
        "}"
      ), source, useBytes = TRUE)
      .cache_stats$typst_calls <- .cache_stats$typst_calls + 1L
      output <- suppressWarnings(system2(typst,
        c("query", shQuote(source), shQuote("<r2cetz-metrics>"),
          "--field", "value", "--one", "--jobs", "2"), stdout = TRUE, stderr = errors))
      status <- attr(output, "status")
      if (!is.null(status) && status != 0L)
        stop("Typst text measurement failed:\n", paste(readLines(errors, warn = FALSE), collapse = "\n"),
             call. = FALSE)
      result <- as.double(jsonlite::fromJSON(paste(output, collapse = "\n")))
      if (length(result) != 3L || any(!is.finite(result)))
        stop("Invalid metrics returned by Typst", call. = FALSE)
    }
    .cache_put(key, as.double(result), state$cache_dir)
    as.double(result)
  }
}
