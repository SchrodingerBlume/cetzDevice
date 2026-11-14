.colour <- function(hex) {
  if (substr(hex, 8L, 9L) == "00") "none" else paste0("rgb(", .str(hex), ")")
}

.stroke <- function(style, unit = 0.75) {
  if (style$lty == -1L || style$lwd <= 0 || .colour(style$col) == "none") return("none")
  out <- paste0("(paint: ", .colour(style$col), ", thickness: ",
                .num(style$lwd * unit), "pt, cap: ",
                .str(c("round", "butt", "square")[[style$lend]]),
                ", join: ", .str(c("round", "miter", "bevel")[[style$ljoin]]),
                ", miter-limit: ", .num(style$lmitre))
  if (style$lty != 0L) {
    value <- style$lty
    pattern <- numeric()
    for (i in seq_len(8L)) {
      digit <- bitwAnd(value, 15L)
      if (digit == 0L) break
      pattern <- c(pattern, digit * max(1, style$lwd) * unit)
      value <- bitwShiftR(value, 4L)
    }
    if (length(pattern))
      out <- paste0(out, ", dash: (array: (", paste0(.num(pattern), "pt", collapse = ", "),
                    ",), phase: 0pt)")
  }
  paste0(out, ")")
}

.point <- function(x, y) paste0("(", .num(x), ", ", .num(y), ")")

.points <- function(x, y) paste(.point(x, y), collapse = ", ")

.stroke_ref <- function(style, state) {
  key <- paste(unlist(style[c("col", "lwd", "lty", "lend", "ljoin", "lmitre")]), collapse = ":")
  id <- state$stroke_keys[[key]]
  if (is.null(id)) {
    id <- length(state$strokes) + 1L
    state$strokes[[id]] <- .stroke(style, state$lwd_unit)
    state$stroke_keys[[key]] <- id
  }
  paste0("r-strokes.at(", id - 1L, ")")
}

.operation <- function(op, state) {
  d <- op$data
  if (op$kind == "raster") return(.raster_operation(d))
  if (op$kind == "annotation") return(d$code)
  if (op$kind == "node") {
    colour <- .colour(op$style$col)
    body <- .text_expr(d$content, op$style, state, if (colour != "none") colour)
    if (colour == "none") body <- paste0("std.hide(", body, ")")
    if (.resolve_label(d$content, state)$mode != "plain") {
      body <- paste0("box(text(top-edge: \"bounds\", bottom-edge: \"bounds\", ", body, "))")
      if (d$anchor %in% c("text", "base-west", "base", "base-east")) {
        descent <- state$measure(d$content, op$style)[3L]
        radians <- d$angle * pi / 180
        d$xy <- d$xy + c(sin(radians), -cos(radians)) * descent
        d$anchor <- switch(d$anchor, text = "south-west", `base-west` = "south-west",
                           base = "south", `base-east` = "south-east")
      }
    }
    return(paste0("content(", .point(d$xy[1L], d$xy[2L]), ", ", body,
      ", angle: ", .num(d$angle), "deg, anchor: ", .str(d$anchor),
      if (!is.null(d$name)) paste0(", name: ", .str(d$name)),
      if (!is.null(d$options) && nzchar(d$options)) paste0(", ", d$options), ")"))
  }
  s <- op$style
  stroke <- if (op$kind != "text") .stroke_ref(s, state)
  patterned <- !is.na(s$pattern) && op$kind %in% c("rect", "circle", "polygon", "path")
  fill <- if (patterned) "none" else .colour(s$fill)
  command <- switch(op$kind,
    line = paste0("line(", .points(d[c(1L, 3L)], d[c(2L, 4L)]),
                  ", stroke: ", stroke, ")"),
    rect = paste0("rect(", .points(d[c(1L, 3L)], d[c(2L, 4L)]),
                  ", stroke: ", stroke, ", fill: ", fill, ")"),
    circle = paste0("circle(", .point(d[1L], d[2L]), ", radius: ", .num(d[3L]),
                    ", stroke: ", stroke, ", fill: ", fill, ")"),
    polyline = paste0("line(", .points(d[[1L]], d[[2L]]), ", stroke: ", stroke, ")"),
    polygon = paste0("line(", .points(d[[1L]], d[[2L]]), ", close: true, stroke: ",
                     stroke, ", fill: ", fill, ")"),
    path = {
      ends <- cumsum(d[[3L]])
      starts <- c(1L, if (length(ends) > 1L) ends[-length(ends)] + 1L)
      paths <- vapply(seq_along(ends), function(i) {
        idx <- seq.int(starts[i], ends[i])
        paste0("  line(", .points(d[[1L]][idx], d[[2L]][idx]), ", close: true)")
      }, character(1L))
      paste0("compound-path({\n", paste(paths, collapse = "\n"),
             "\n}, stroke: ", stroke, ", fill: ", fill, ", fill-rule: ",
             .str(if (d[[4L]]) "non-zero" else "even-odd"), ")")
    },
    text = {
      if (.colour(s$col) == "none") return(NULL)
      at <- d[[1L]]
      # Shift the baseline origin by the requested horizontal adjustment.
      width <- state$measure(d[[2L]], s)[1L]
      angle <- at[3L] * pi / 180
      x <- at[1L] - at[4L] * width * cos(angle)
      y <- at[2L] - at[4L] * width * sin(angle)
      body <- .text_expr(d[[2L]], s, state, .colour(s$col))
      if (.resolve_label(d[[2L]], state)$mode == "plain") {
        paste0("content(", .point(x, y), ", anchor: \"text\", angle: ",
               .num(at[3L]), "deg, ", body, ")")
      } else {
        descent <- state$measure(d[[2L]], s)[3L]
        paste0("content(", .point(x + descent * sin(angle), y - descent * cos(angle)),
               ", anchor: \"south-west\", angle: ", .num(at[3L]),
               "deg, box(text(top-edge: \"bounds\", bottom-edge: \"bounds\", ", body, ")))")
      }
    },
    stop("Unknown drawing operation: ", op$kind, call. = FALSE)
  )
  if (patterned) c(.gradient_operation(op), command) else command
}

.layer <- function(commands, clip, state) {
  if (!length(commands)) return(NULL)
  x <- max(0, min(clip[1:2]))
  right <- min(state$width, max(clip[1:2]))
  bottom <- max(0, min(clip[3:4]))
  top <- min(state$height, max(clip[3:4]))
  if (right <= x || top <= bottom) return(NULL)
  list(clip = c(x, right, bottom, top), commands = commands)
}

.finish_page <- function(state) {
  if (!state$started) return(invisible(NULL))
  full <- c(0, state$width, 0, state$height)
  clip <- drawing_clip <- full
  # Preallocate buffers instead of repeatedly copying all preceding commands.
  commands <- vector("list", state$count)
  layers <- vector("list", state$count + 1L)
  command_count <- layer_count <- 0L
  flush <- function() {
    layer <- .layer(unlist(commands[seq_len(command_count)], use.names = FALSE), clip, state)
    if (!is.null(layer)) {
      layer_count <<- layer_count + 1L
      layers[[layer_count]] <<- layer
    }
    command_count <<- 0L
  }
  for (i in seq_len(state$count)) {
    op <- state$ops[[as.character(i)]]
    if (op$kind == "clip") {
      drawing_clip <- op$data
    } else {
      wanted <- if (op$kind %in% c("annotation", "node") && !op$data$clip) full else drawing_clip
      if (!identical(clip, wanted)) { flush(); clip <- wanted }
      command_count <- command_count + 1L
      commands[[command_count]] <- .operation(op, state)
    }
  }
  flush()
  state$pages[[length(state$pages) + 1L]] <- list(
    layers = layers[seq_len(layer_count)], coords = state$coords,
    background = .colour(state$background))
  state$started <- FALSE
  invisible(NULL)
}

.module_lines <- function(state, pages) {
  layers <- unlist(lapply(pages, function(page) {
    c("  (", unlist(lapply(page$layers, function(layer) {
      c(paste0("    (clip: (", paste(.num(layer$clip), collapse = ", "), "), draw: () => {"),
        "      import cetz.draw: *", paste0("      ", layer$commands), "    }),")
    }), use.names = FALSE), "  ),")
  }), use.names = FALSE)
  coordinates <- vapply(pages, function(page) {
    if (!length(page$coords)) return("  (:),")
    paste0("  (", paste(vapply(names(page$coords), function(name) {
      xy <- page$coords[[name]]
      paste0(.str(name), ": ", .point(xy[1L], xy[2L]))
    }, character(1L)), collapse = ", "), ",),")
  }, character(1L))
  lines <- c(
    "// Generated by cetzDevice. Coordinates and line widths are in points.",
    "// Import r-figure and call r-figure(page: 1) to include this plot.",
    .cetz_import(),
    .typst_header(state),
    "",
    .image_definitions(state$images),
    paste0("#let r-patterns = (", paste(vapply(state$patterns, .str, character(1L)), collapse = ", "),
           if (length(state$patterns)) ",", ")"),
    if (length(state$patterns))
      readLines(system.file("typst", "gradients.typ", package = "cetzDevice"), warn = FALSE),
    paste0("#let r-size = ", .point(state$width, state$height)),
    paste0("#let r-strokes = (", paste(unlist(state$strokes), collapse = ", "),
           if (length(state$strokes)) ",", ")"),
    "#let r-layers = (", layers, ")",
    "#let r-coordinates = (", coordinates, ")",
    paste0("#let r-backgrounds = (", paste(vapply(pages, `[[`, character(1L), "background"), collapse = ", "),
           if (length(pages)) ",", ")"),
    readLines(system.file("typst", "scene.typ", package = "cetzDevice"), warn = FALSE),
    readLines(system.file("typst", "runtime.typ", package = "cetzDevice"), warn = FALSE)
  )
  if (state$standalone && length(pages)) {
    lines <- c(lines, "",
      paste0("#set page(width: ", .num(state$width), "pt, height: ",
             .num(state$height), "pt, margin: 0pt, fill: none)"),
      "#set par(leading: 0pt, spacing: 0pt)",
      "#for (i, draw) in r-figures.enumerate() {",
      "  if i > 0 { pagebreak() }",
      "  draw()",
      "}")
  }
  lines
}

.write_device <- function(state) {
  if (state$console) {
    cat(.module_lines(state, state$pages), sep = "\n")
    return(invisible(NULL))
  }
  outputs <- if (state$onefile) list(state$pages) else lapply(state$pages, list)
  for (i in seq_along(outputs)) {
    file <- if (state$onefile) state$file else file.path(dirname(state$file), sprintf(basename(state$file), i))
    .write_source(.module_lines(state, outputs[[i]]), file)
  }
  invisible(NULL)
}

.write_source <- function(lines, file) {
  # Serialize completely before replacing an existing output file.
  temp <- tempfile(".cetz-", tmpdir = dirname(file))
  on.exit(unlink(temp), add = TRUE)
  writeLines(lines, temp, useBytes = TRUE)
  if (.Platform$OS.type == "windows" && file.exists(file)) {
    if (!file.copy(temp, file, overwrite = TRUE)) stop("Could not replace output file: ", file, call. = FALSE)
  } else if (!file.rename(temp, file)) stop("Could not replace output file: ", file, call. = FALSE)
  invisible(NULL)
}
