#' CeTZ Graphics Device
#'
#' Open an R graphics device which records plotting commands as CeTZ source
#' for Typst documents. Close the device with dev.off() to write the output.
#' See vignette("cetzDevice") for usage and examples.
#'
#' @param file Output Typst source file.
#' @param width,height Device dimensions in inches.
#' @param pointsize Initial font size in points.
#' @param family Default font family. Use a font available to Typst.
#' @param bg Background colour, including "transparent".
#' @param standalone Whether to include page setup and render every page.
#' @param metrics Text measurement backend: "typst" (accurate, cached) or
#'   "systemfonts" (faster, approximate).
#' @param typst Path to the Typst CLI executable.
#' @param font_map Named character vector mapping R font families to Typst fonts.
#' @param text_mode Interpretation of unmarked text: plain, typst or latex.
#' @param preamble Typst source lines shared by measurements and output.
#' @param cache_dir Optional persistent metric cache directory.
#' @param cache_key Additional invalidation key for fonts or dynamic dependencies.
#' @param fg Initial foreground colour.
#' @param lwd_unit Typst points per R line-width unit.
#' @param onefile Write all pages to one module, or use an integer filename pattern.
#' @param console Print the module to standard output.
#' @return Invisibly, the device number.
#' @export
cetz <- function(file = "Rplots.typ", width = 7, height = 7, pointsize = 12,
                 family = "Arial", bg = "white", standalone = FALSE,
                 metrics = c("typst", "systemfonts"),
                 typst = Sys.which("typst"),
                 font_map = c(sans = "Arial", serif = "Times New Roman",
                               mono = "Courier New", symbol = "Symbol"),
                 text_mode = c("plain", "typst", "latex"), preamble = character(),
                 cache_dir = NULL, cache_key = "default", fg = "black",
                 lwd_unit = 0.75, onefile = TRUE, console = FALSE) {
  scalar_string <- function(x) is.character(x) && length(x) == 1L &&
    !is.na(x) && nzchar(x)
  if (!is.character(file) || length(file) != 1L || is.na(file))
    stop("'file' must be a single path", call. = FALSE)
  if (!nzchar(file)) console <- TRUE
  for (name in c("width", "height", "pointsize", "lwd_unit")) {
    x <- get(name)
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0)
      stop("'", name, "' must be a positive finite number", call. = FALSE)
  }
  if (!scalar_string(family)) stop("'family' must name a font", call. = FALSE)
  if (!is.logical(standalone) || length(standalone) != 1L || is.na(standalone))
    stop("'standalone' must be TRUE or FALSE", call. = FALSE)
  for (name in c("onefile", "console")) {
    x <- get(name)
    if (!is.logical(x) || length(x) != 1L || is.na(x))
      stop("'", name, "' must be TRUE or FALSE", call. = FALSE)
  }
  if (console && !onefile) stop("Console output requires onefile = TRUE", call. = FALSE)
  if (!onefile && (!grepl("%0?[0-9]*d", basename(file)) ||
      grepl("%", sub("%0?[0-9]*d", "", basename(file)))))
    stop("For onefile = FALSE, 'file' must contain one integer placeholder, e.g. %03d", call. = FALSE)
  if (!is.character(font_map) || anyNA(font_map) || any(!nzchar(font_map)) ||
      (length(font_map) && (is.null(names(font_map)) || any(!nzchar(names(font_map))))))
    stop("'font_map' must be a named character vector", call. = FALSE)
  metrics <- match.arg(metrics)
  text_mode <- match.arg(text_mode)
  if (!is.character(preamble) || anyNA(preamble))
    stop("'preamble' must be a character vector of Typst source lines", call. = FALSE)
  if (!scalar_string(cache_key)) stop("'cache_key' must be a non-empty string", call. = FALSE)
  if (metrics == "systemfonts" && text_mode != "plain")
    stop("Typst/MiTeX labels require metrics = 'typst'", call. = FALSE)
  if (!is.null(cache_dir)) {
    if (!scalar_string(cache_dir)) stop("'cache_dir' must be a directory path", call. = FALSE)
    cache_dir <- path.expand(cache_dir)
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    cache_dir <- normalizePath(cache_dir, mustWork = TRUE)
    if (file.access(cache_dir, 2L) != 0L) stop("Cache directory is not writable", call. = FALSE)
  }
  if (metrics == "typst" && (!scalar_string(typst) || !file.exists(typst)))
    stop("Typst CLI not found; install Typst or use metrics = 'systemfonts'", call. = FALSE)
  if (metrics == "systemfonts" && !requireNamespace("systemfonts", quietly = TRUE))
    stop("Install 'systemfonts' to use metrics = 'systemfonts'", call. = FALSE)
  file <- if (console) tempfile(".cetz-console-", tmpdir = getwd(), fileext = ".typ") else path.expand(file)
  parent <- normalizePath(dirname(file), mustWork = TRUE)
  file <- file.path(parent, basename(file))
  if (dir.exists(file) || file.access(parent, 2L) != 0L ||
      (file.exists(file) && file.access(file, 2L) != 0L))
    stop("Output path is not writable: ", file, call. = FALSE)
  rgba <- grDevices::col2rgb(bg, alpha = TRUE)
  if (ncol(rgba) != 1L) stop("'bg' must be a single colour", call. = FALSE)
  # A double preserves all 32 bits of an unsigned ABGR color.
  background <- sum(as.double(rgba[, 1L]) * 256^(0:3))
  state <- new.env(parent = emptyenv())
  state$file <- file
  state$width <- width * 72
  state$height <- height * 72
  state$family <- family
  state$font_map <- font_map
  state$metrics_backend <- metrics
  state$resolved_fonts <- new.env(parent = emptyenv())
  state$standalone <- standalone
  state$onefile <- onefile
  state$console <- console
  state$lwd_unit <- lwd_unit
  state$text_mode <- text_mode
  state$needs_mitex <- text_mode == "latex"
  state$preamble <- preamble
  state$cache_dir <- cache_dir
  state$cache_key <- cache_key
  state$pages <- list()
  state$coords <- list()
  state$strokes <- list()
  state$stroke_keys <- new.env(parent = emptyenv())
  state$images <- list()
  state$patterns <- list()
  state$pattern_keys <- new.env(parent = emptyenv())
  state$ops <- new.env(parent = emptyenv())
  state$count <- 0L
  state$started <- FALSE
  state$error <- NULL
  foreground <- grDevices::col2rgb(fg, alpha = TRUE)
  if (ncol(foreground) != 1L) stop("'fg' must be a single colour", call. = FALSE)
  foreground <- sum(as.double(foreground[, 1L]) * 256^(0:3))
  state$temp <- tempfile("cetz-metrics-")
  # Resolve relative imports beside the output file.
  state$metric_source <- tempfile(".cetz-measure-", tmpdir = parent, fileext = ".typ")
  dir.create(state$temp)
  success <- FALSE
  cleanup <- function() {
    unlink(state$temp, recursive = TRUE)
    unlink(state$metric_source)
  }
  on.exit(if (!success) cleanup(), add = TRUE)
  measure <- .metric_backend(state, metrics, typst)
  state$measure <- measure
  # Fail before registering the device if the metric backend cannot run.
  measure("M", list(family = "", face = 1L, size = pointsize))
  emit <- function(kind, data, style) {
    if (kind == "close") {
      on.exit({
        cleanup()
        if (!is.null(state$id)) .devices[[as.character(state$id)]] <- NULL
      }, add = TRUE)
      tryCatch(suppressWarnings({ .finish_page(state); .write_device(state) }), error = function(e) {
        state$error <- e
      })
      if (!is.null(state$error)) return(conditionMessage(state$error))
    } else if (kind == "pattern") {
      return(.record_pattern(data, state))
    } else if (kind == "page") {
      .finish_page(state)
      state$started <- TRUE
      state$count <- 0L
      state$ops <- new.env(parent = emptyenv())
      state$coords <- list()
      state$background <- style$fill
    } else if (state$started) {
      if (kind == "raster") data <- .record_raster(data, state)
      .record_op(state, kind, data, style)
    }
    invisible(NULL)
  }
  .Call(cetz_device, list(emit, measure), as.double(width), as.double(height),
        as.double(pointsize), background, foreground)
  state$id <- grDevices::dev.cur()
  .devices[[as.character(state$id)]] <- state
  success <- TRUE
  invisible(grDevices::dev.cur())
}

#' Save a plot as CeTZ source
#'
#' @param file Output Typst source file.
#' @param plot A plot object to print, such as a ggplot object, or a zero-argument
#'   function that performs base or grid drawing.
#' @param ... Arguments passed to cetz().
#' @return Invisibly, the output path.
#' @export
cetz_save <- function(file, plot, ...) {
  if (missing(plot)) stop("Supply a plot object or a drawing function", call. = FALSE)
  device <- cetz(file = file, ...)
  state <- .devices[[as.character(device)]]
  on.exit({
    if (device %in% grDevices::dev.list()) grDevices::dev.off(device)
  }, add = TRUE)
  # Unwind the drawing call before closing the device.
  drawing_error <- tryCatch({
    if (is.function(plot)) plot() else print(plot)
    NULL
  }, error = function(e) e)
  grDevices::dev.off(device)
  if (!is.null(drawing_error)) stop(drawing_error)
  if (!is.null(state$error)) stop(state$error)
  invisible(file)
}
