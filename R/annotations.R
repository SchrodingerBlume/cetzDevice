.devices <- new.env(parent = emptyenv())

.active_state <- function() {
  state <- .devices[[as.character(grDevices::dev.cur())]]
  if (is.null(state)) stop("The active device is not a cetzDevice", call. = FALSE)
  if (!state$started) stop("Start a plot before adding CeTZ annotations", call. = FALSE)
  state
}

.record_op <- function(state, kind, data, style = NULL) {
  state$count <- state$count + 1L
  state$ops[[as.character(state$count)]] <- list(kind = kind, data = data, style = style)
  invisible(NULL)
}

.device_xy <- function(x, y, units) {
  if (!is.numeric(x) || !is.numeric(y) || length(x) != 1L || length(y) != 1L ||
      !is.finite(x) || !is.finite(y)) stop("Coordinates must be finite numeric scalars", call. = FALSE)
  c(graphics::grconvertX(x, from = units, to = "device"),
    graphics::grconvertY(y, from = units, to = "device"))
}

.register_coord <- function(state, xy, name) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name) ||
      grepl("[.]", name)) stop("Coordinate names must be non-empty strings without dots", call. = FALSE)
  if (name %in% names(state$coords)) stop("Duplicate coordinate name: ", name, call. = FALSE)
  state$coords[[name]] <- xy
  invisible(NULL)
}

#' Insert CeTZ drawing code in the active plot
#' @param code Character vector of CeTZ code lines, in code mode without # prefixes.
#' @param clip Use the current R clipping rectangle, rather than the full page.
#' @return Invisibly, NULL.
#' @export
cetz_annotate <- function(code, clip = FALSE) {
  state <- .active_state()
  if (!is.character(code) || anyNA(code)) stop("'code' must contain CeTZ source lines", call. = FALSE)
  if (!is.logical(clip) || length(clip) != 1L || is.na(clip)) stop("'clip' must be TRUE or FALSE", call. = FALSE)
  .record_op(state, "annotation", list(code = code, clip = clip))
}

#' Define a named CeTZ coordinate from an R position
#' @param x,y Coordinates in the specified base graphics units.
#' @param name A unique coordinate name within the page, without dots.
#' @param units Base graphics coordinate system, as in grconvertX().
#' @return Invisibly, the position in device points.
#' @export
cetz_coord <- function(x, y, name, units = "user") {
  state <- .active_state()
  xy <- .device_xy(x, y, units)
  .register_coord(state, xy, name)
  invisible(xy)
}

#' Place a CeTZ content node in the active plot
#' @param x,y Coordinates in the specified base graphics units.
#' @param content A scalar text/numeric/logical label, or a cetz_typst()/cetz_latex() label.
#' @param name Optional name for the node, available across CeTZ layers.
#' @param units Base graphics coordinate system.
#' @param angle Rotation in degrees, counterclockwise.
#' @param anchor CeTZ content anchor.
#' @param options Additional CeTZ style arguments as code, e.g. "frame: \"rect\"".
#' @param clip Whether to clip the node to the current R panel.
#' @return Invisibly, NULL.
#' @export
cetz_node <- function(x, y, content, name = NULL, units = "user", angle = 0,
                      anchor = "center", options = NULL, clip = FALSE) {
  state <- .active_state()
  .node_at(state, .device_xy(x, y, units), content, name, angle, anchor, options, clip)
}

.node_at <- function(state, xy, content, name, angle, anchor, options, clip,
                     style = NULL) {
  scalar <- function(x) is.character(x) && length(x) == 1L && !is.na(x)
  if ((is.numeric(content) || is.logical(content)) && length(content) == 1L && !is.na(content))
    content <- as.character(content)
  if (!scalar(content)) stop("'content' must be a single label", call. = FALSE)
  if ((!is.null(name) && !scalar(name)) || !scalar(anchor) ||
      (!is.null(options) && !scalar(options))) stop("Invalid node name, anchor or options", call. = FALSE)
  if (!is.null(name) && (!nzchar(name) || grepl("[.]", name)))
    stop("Node names must be non-empty strings without dots", call. = FALSE)
  if (!is.numeric(angle) || length(angle) != 1L || !is.finite(angle))
    stop("'angle' must be finite", call. = FALSE)
  if (!is.logical(clip) || length(clip) != 1L || is.na(clip)) stop("'clip' must be TRUE or FALSE", call. = FALSE)
  if (is.null(style)) {
    p <- graphics::par(c("family", "font", "ps", "cex", "col"))
    rgba <- grDevices::col2rgb(p$col, alpha = TRUE)[, 1L]
    style <- list(family = p$family, face = p$font, size = p$ps * p$cex,
                  col = grDevices::rgb(rgba[1L], rgba[2L], rgba[3L], rgba[4L], maxColorValue = 255))
  }
  # Measure now so invalid markup fails at the annotation call, not dev.off().
  state$measure(content, style)
  .record_op(state, "node", list(xy = xy, content = content, name = name,
    angle = angle, anchor = anchor, options = options, clip = clip), style)
}

#' Create a grid grob that inserts CeTZ code
#' @inheritParams cetz_annotate
#' @return A grid grob.
#' @export
cetz_annotate_grob <- function(code, clip = FALSE) {
  grid::grob(code = code, clip = clip, cl = "cetz_annotation")
}

#' @export
drawDetails.cetz_annotation <- function(x, recording = TRUE) cetz_annotate(x$code, x$clip)

#' Create a named CeTZ coordinate in grid graphics
#' @param x,y Grid positions, numeric or unit objects.
#' @param name A unique coordinate name within the page.
#' @param units Units used for numeric positions.
#' @return A grid grob.
#' @export
cetz_coord_grob <- function(x, y, name, units = "native") {
  if (!grid::is.unit(x)) x <- grid::unit(x, units)
  if (!grid::is.unit(y)) y <- grid::unit(y, units)
  if (length(x) != 1L || length(y) != 1L) stop("Grid positions must be single units", call. = FALSE)
  grid::grob(x = x, y = y, coord_name = name, cl = "cetz_coordinate")
}

#' @export
drawDetails.cetz_coordinate <- function(x, recording = TRUE) {
  at <- grid::deviceLoc(x$x, x$y, valueOnly = TRUE)
  .register_coord(.active_state(), c(at$x, at$y) * 72, x$coord_name)
}

#' Create a CeTZ content node in grid graphics
#' @inheritParams cetz_coord_grob
#' @inheritParams cetz_node
#' @param gp Grid graphical parameters for the text.
#' @return A grid grob.
#' @export
cetz_node_grob <- function(x, y, content, name = NULL, units = "native", angle = 0,
                           anchor = "center", options = NULL, clip = FALSE, gp = grid::gpar()) {
  if (!grid::is.unit(x)) x <- grid::unit(x, units)
  if (!grid::is.unit(y)) y <- grid::unit(y, units)
  if (length(x) != 1L || length(y) != 1L) stop("Grid positions must be single units", call. = FALSE)
  grid::grob(x = x, y = y, content = content, node_name = name, angle = angle,
             anchor = anchor, options = options, clip = clip, gp = gp, cl = "cetz_node")
}

#' @export
drawDetails.cetz_node <- function(x, recording = TRUE) {
  at <- grid::deviceLoc(x$x, x$y, valueOnly = TRUE)
  gp <- grid::get.gpar(c("fontfamily", "font", "fontsize", "cex", "col", "alpha"))
  rgba <- grDevices::col2rgb(gp$col[1L], alpha = TRUE)
  rgba[4L, ] <- round(rgba[4L, ] * gp$alpha[1L])
  style <- list(family = gp$fontfamily[1L], face = gp$font[1L],
                size = gp$fontsize[1L] * gp$cex[1L],
                col = grDevices::rgb(rgba[1L, 1L], rgba[2L, 1L], rgba[3L, 1L],
                                     rgba[4L, 1L], maxColorValue = 255))
  .node_at(.active_state(), c(at$x, at$y) * 72, x$content, x$node_name,
            x$angle + grid::current.rotation(),
            x$anchor, x$options, x$clip, style)
}
