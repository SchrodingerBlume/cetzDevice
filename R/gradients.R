.record_pattern <- function(data, state) {
  type <- data[[1L]]
  at <- data[[2L]]
  stops <- data[[3L]]
  colours <- data[[4L]]
  extend <- c("pad", "repeat", "reflect", "none")[[data[[5L]]]]
  if (any(!is.finite(c(at, stops))) || !length(stops) ||
      any(stops < 0 | stops > 1) || any(diff(stops) < 0))
    stop("Invalid gradient coordinates or colour stops", call. = FALSE)
  if (type == 2L && any(at[c(3L, 6L)] < 0)) stop("Negative radial gradient radius", call. = FALSE)
  if (type == 2L && at[3L] > at[6L]) {
    at <- at[c(4L, 5L, 6L, 1L, 2L, 3L)]
    stops <- 1 - rev(stops)
    colours <- rev(colours)
  }
  if (type == 2L && (at[6L] <= at[3L] ||
      sqrt(sum((at[1:2] - at[4:5])^2)) + at[3L] > at[6L] + 1e-6))
    stop("Radial gradient circles must be nested with different radii", call. = FALSE)
  pattern <- list(type = type, at = at, stops = stops, colours = colours, extend = extend)
  key <- digest::digest(pattern, algo = "sha256")
  id <- state$pattern_keys[[key]]
  if (is.null(id)) {
    id <- length(state$patterns) + 1L
    state$patterns[[id]] <- .gradient_definition(pattern)
    state$pattern_keys[[key]] <- id
  }
  as.integer(id)
}

.gradient_definition <- function(pattern) {
  at <- pattern$at
  stops <- pattern$stops
  colours <- pattern$colours
  if (pattern$extend == "none") {
    # Duplicate endpoint stops give transparent pad colours outside [0, 1].
    stops <- c(0, 0, stops, 1, 1)
    colours <- c(paste0(substr(colours[1L], 1L, 7L), "00"), colours[1L], colours,
                 colours[length(colours)], paste0(substr(colours[length(colours)], 1L, 7L), "00"))
  }
  tag <- if (pattern$type == 1L) "linearGradient" else "radialGradient"
  attrs <- if (pattern$type == 1L) {
    paste0('x1="', .num(at[1L]), '" y1="', .num(-at[2L]),
           '" x2="', .num(at[3L]), '" y2="', .num(-at[4L]), '"')
  } else {
    paste0('fx="', .num(at[1L]), '" fy="', .num(-at[2L]), '" fr="', .num(at[3L]),
           '" cx="', .num(at[4L]), '" cy="', .num(-at[5L]), '" r="', .num(at[6L]), '"')
  }
  nodes <- paste0('<stop offset="', .num(stops), '" stop-color="', substr(colours, 1L, 7L),
                   '" stop-opacity="', .num(strtoi(substr(colours, 8L, 9L), 16L) / 255), '"/>')
  paste0('<', tag, ' id="r-gradient" gradientUnits="userSpaceOnUse" color-interpolation="sRGB" ',
         attrs, ' spreadMethod="', if (pattern$extend == "none") "pad" else pattern$extend, '">',
         paste(nodes, collapse = ""), '</', tag, '>')
}

.gradient_shape <- function(op) {
  d <- op$data
  if (op$kind == "rect") {
    x <- range(d[c(1L, 3L)])
    y <- range(d[c(2L, 4L)])
    shape <- paste0('<rect x="', .num(x[1L]), '" y="', .num(-y[2L]),
      '" width="', .num(diff(x)), '" height="', .num(diff(y)), '"')
  } else if (op$kind == "circle") {
    x <- d[1L] + c(-1, 1) * d[3L]
    y <- d[2L] + c(-1, 1) * d[3L]
    shape <- paste0('<circle cx="', .num(d[1L]), '" cy="', .num(-d[2L]),
                     '" r="', .num(d[3L]), '"')
  } else {
    x <- range(d[[1L]])
    y <- range(d[[2L]])
    counts <- if (op$kind == "path") d[[3L]] else length(d[[1L]])
    ends <- cumsum(counts)
    starts <- c(1L, if (length(ends) > 1L) ends[-length(ends)] + 1L)
    parts <- vapply(seq_along(ends), function(i) {
      idx <- seq.int(starts[i], ends[i])
      paste0("M", paste(paste(.num(d[[1L]][idx]), .num(-d[[2L]][idx])), collapse = " L"), " Z")
    }, character(1L))
    shape <- paste0('<path d="', paste(parts, collapse = " "), '" fill-rule="',
                     if (op$kind == "path" && !d[[4L]]) "evenodd" else "nonzero", '"')
  }
  list(bounds = c(x[1L], y[1L], x[2L], y[2L]),
       shape = paste0(shape, ' fill="url(#r-gradient)"/>'))
}

.gradient_operation <- function(op) {
  shape <- .gradient_shape(op)
  bounds <- shape$bounds
  if (bounds[3L] - bounds[1L] < 1e-6 || bounds[4L] - bounds[2L] < 1e-6)
    return(character())
  paste0("r-gradient-fill(", op$style$pattern - 1L, ", (",
         paste(.num(bounds), collapse = ", "), "), ", .str(shape$shape), ")")
}
