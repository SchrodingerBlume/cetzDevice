test_that("named nodes and raw shape anchors survive clipping changes", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(width = 0.8, height = 0.8, clip = "on"))
    grid::grid.rect(gp = grid::gpar(fill = "white", col = "#2673b8"))
    cetz_node(150, 90, "Across layers", units = "device", name = "label", clip = TRUE,
              options = 'frame: "rect", padding: 3')
    cetz_annotate('circle((36,40), radius: 8, name: "raw", fill: green)', clip = TRUE)
    grid::popViewport()
    grid::grid.lines(x = c(0.1, 0.9), y = c(0.2, 0.2))
    cetz_annotate('line("raw.north", "label.south", stroke: red, mark: (end: ">"))')
    expect_error(cetz_node(1, 1, "bad", name = "bad.name"), "Node names")
  }, width = 3, height = 2, metrics = "systemfonts", standalone = TRUE)
  compile_svg(file)
})

scene_ink <- function(pixels) {
  pmax(pixels[, , 1L], pixels[, , 2L], pixels[, , 3L]) < 0.25
}

scene_dilate <- function(mask, radius = 2L) {
  result <- mask
  for (dy in -radius:radius) for (dx in -radius:radius) {
    rows <- seq.int(max(1L, 1L + dy), min(nrow(mask), nrow(mask) + dy))
    cols <- seq.int(max(1L, 1L + dx), min(ncol(mask), ncol(mask) + dx))
    result[rows, cols] <- result[rows, cols] | mask[rows - dy, cols - dx]
  }
  result
}

test_that("clipped embedding transforms whole content and exported anchors consistently", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-affine-scene-")
  dir.create(directory)
  file <- file.path(directory, "figure.typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))
    grid::grid.rect(x = 0.25, y = 0.75, width = 0.5, height = 0.5,
                    gp = grid::gpar(fill = "red", col = NA))
    grid::grid.rect(x = 0.75, y = 0.75, width = 0.5, height = 0.5,
                    gp = grid::gpar(fill = "green", col = NA))
    grid::grid.rect(x = 0.25, y = 0.25, width = 0.5, height = 0.5,
                    gp = grid::gpar(fill = "blue", col = NA))
    grid::grid.text("Affine", x = 0.75, y = 0.25, gp = grid::gpar(col = "black", fontsize = 20))
    cetz_annotate('circle((36,40), radius: 8, name: "raw", stroke: none, fill: rgb("#70af95"))')
  }, width = 3, height = 2, metrics = "systemfonts", standalone = TRUE)
  original <- png::readPNG(compile_png(file))
  ink <- which(scene_ink(original), arr.ind = TRUE)
  points <- cbind(ink[, 2L] - 0.5, 144 - ink[, 1L] + 0.5)
  cases <- list(
    list(a = 0, b = -1, c = 1, d = 0, x = 320, y = 100),
    list(a = 1.3, b = 0, c = 0, d = 0.65, x = 110, y = 170),
    list(a = 0.75, b = 0.35, c = 0.15, d = 1.1, x = 150, y = 120),
    list(a = -1, b = 0, c = 0, d = 1, x = 350, y = 100),
    list(a = 0.8, b = -0.25, c = 0.25, d = 0.8, x = 180, y = 130, angle = 17),
    list(a = 0.8, b = 0, c = 0, d = 0.8, x = 6, y = 4, unit = "1cm"))
  for (mode in c("r-draw", "r-elements")) {
    for (i in seq_along(cases)) {
      case <- cases[[i]]
      angle <- if (is.null(case$angle) || mode == "r-elements") 0 else case$angle
      unit <- if (is.null(case$unit) || mode == "r-elements") "1pt" else case$unit
      # Raw elements use points by contract; keep their translation in points.
      if (mode == "r-elements" && !is.null(case$unit)) { case$x <- 170; case$y <- 113 }
      q <- if (unit == "1pt") 1 else 72 / 2.54
      radians <- angle * pi / 180
      rotation <- matrix(c(cos(radians), sin(radians), -sin(radians), cos(radians)), 2)
      linear <- matrix(c(case$a, case$c, case$b, case$d), 2) %*% rotation
      translate <- c(case$x, case$y) * q
      expected_anchor <- as.vector(linear %*% c(36, 48) + translate) / q
      matrix_code <- sprintf("((%s,%s,0,%s),(%s,%s,0,%s),(0,0,1,0),(0,0,0,1))",
        case$a, case$b, case$x, case$c, case$d, case$y)
      document <- file.path(directory, sprintf("%s-%d.typ", mode, i))
      invocation <- if (mode == "r-draw") sprintf('r-draw(name: "plot", angle: %sdeg)', angle) else
        'r-elements(clip: true)'
      anchor <- if (mode == "r-draw") '(ctx.nodes.at("plot").anchors)(("raw", "north"))' else
        '(ctx.nodes.at("raw").anchors)("north")'
      writeLines(c(
        '#import "figure.typ": r-draw, r-elements',
        sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
        '#set page(width: 500pt, height: 500pt, margin: 0pt, fill: white)',
        sprintf('#cetz.canvas(length: %s, {', unit),
        '  import cetz.draw: *',
        sprintf('  hide(rect((0,0),(500pt/%s,500pt/%s), stroke: none), bounds: true)', unit, unit),
        sprintf('  floating(scope({ set-transform(%s)', matrix_code),
        paste0('    ', invocation),
        '    get-ctx(ctx => {',
        paste0('      let p = ', anchor),
        sprintf('      assert(calc.abs(p.at(0) - %.9f) < 0.001)', expected_anchor[1L]),
        sprintf('      assert(calc.abs(p.at(1) - %.9f) < 0.001)', expected_anchor[2L]),
        '      ()',
        '    })',
        '  }))',
        '})'
      ), document)
      actual <- scene_ink(png::readPNG(compile_png(document)))
      projected <- sweep(points %*% t(linear), 2, translate, "+")
      indices <- cbind(floor(500 - projected[, 2L]) + 1L, floor(projected[, 1L]) + 1L)
      expected <- matrix(FALSE, 500, 500)
      expected[indices] <- TRUE
      expect_gt(sum(actual), 20)
      mismatch <- (sum(actual & !scene_dilate(expected)) + sum(expected & !scene_dilate(actual))) /
        max(1, sum(actual) + sum(expected))
      expect_lt(mismatch, 0.08, label = paste(mode, "affine case", i))
    }
  }
})

test_that("raw elements retain access to names in the containing CeTZ canvas", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-raw-scope-")
  dir.create(directory)
  file <- file.path(directory, "figure.typ")
  with_device(file, function() {
    plot.new()
    cetz_node(108, 72, "Inside", units = "device", name = "inside")
    cetz_annotate('line("outside", "inside.east", stroke: red)')
  }, width = 3, height = 2, metrics = "systemfonts")
  document <- file.path(directory, "main.typ")
  writeLines(c(
    '#import "figure.typ": r-elements',
    sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
    '#set page(width: auto, height: auto, margin: 0pt)',
    '#cetz.canvas(length: 1pt, {',
    '  import cetz.draw: *',
    '  circle((260,150), radius: 3, name: "outside")',
    '  r-elements(background: false)',
    '})'
  ), document)
  compile_svg(document)
})
