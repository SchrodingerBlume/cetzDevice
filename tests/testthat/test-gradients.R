native_gradient_png <- function(draw, width = 4, height = 3) {
  path <- tempfile(fileext = ".png")
  grDevices::png(path, width = width, height = height, units = "in", res = 72,
                  bg = "transparent", type = "cairo")
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  draw()
  grDevices::dev.off(device)
  png::readPNG(path)
}

gradient_samples <- function(pixels, x, y) {
  indices <- cbind(floor(dim(pixels)[1L] * (1 - y)) + 1L,
                    floor(dim(pixels)[2L] * x) + 1L)
  values <- vapply(1:3, function(channel) pixels[, , channel][indices], numeric(length(x)))
  values <- cbind(values, if (dim(pixels)[3L] == 4L) pixels[, , 4L][indices] else 1)
  values[, 1:3] <- values[, 1:3] * values[, 4L]
  round(values * 255)
}

test_that("linear gradients preserve device coordinates, stops, alpha and extension", {
  skip_if_not_installed("systemfonts")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  extensions <- c("pad", "repeat", "reflect", "none")
  draw <- function(extend) {
    grid::grid.newpage()
    grid::grid.rect(gp = grid::gpar(col = NA, fill = grid::linearGradient(
      c("#ff000080", "#00ff00ff", "#0000ff40"), stops = c(0, 0.3, 1),
      x1 = 0.25, y1 = 0.4, x2 = 0.75, y2 = 0.6, extend = extend, group = FALSE)))
  }
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    if (getRversion() >= "4.2.0")
      expect_setequal(grDevices::dev.capabilities()$patterns, c("LinearGradient", "RadialGradient"))
    for (extend in extensions) draw(extend)
  }, width = 4, height = 3, bg = "transparent", metrics = "systemfonts", standalone = TRUE)
  files <- compile_png(file, length(extensions))
  points <- expand.grid(x = c(0.07, 0.33, 0.51, 0.68, 0.91), y = c(0.23, 0.57, 0.79))
  for (i in seq_along(extensions)) {
    reference <- native_gradient_png(function() draw(extensions[i]))
    actual <- png::readPNG(files[i])
    difference <- abs(gradient_samples(actual, points$x, points$y) -
                      gradient_samples(reference, points$x, points$y))
    expect_lte(max(difference), 3, label = paste("linear", extensions[i]))
  }
  svg <- paste(readLines(compile_svg(file), warn = FALSE), collapse = "\n")
  expect_match(svg, "data:image/svg+xml;base64,", fixed = TRUE)
  expect_false(grepl("data:image/png;base64,", svg, fixed = TRUE))
})

test_that("nested radial gradients match R including focal radii and reversed circles", {
  skip_if_not_installed("systemfonts")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  cases <- list(
    list(r1 = 0.12, r2 = 0.4),
    list(cx1 = 0.4, cy1 = 0.6, r1 = 0.04, cx2 = 0.6, cy2 = 0.4, r2 = 0.4),
    list(r1 = 0.4, r2 = 0.05),
    list(r1 = 0.07, r2 = 0.25, extend = "repeat"),
    list(r1 = 0.07, r2 = 0.25, extend = "reflect"),
    list(r1 = 0.07, r2 = 0.25, extend = "none"))
  draw <- function(case) {
    grid::grid.newpage()
    gradient <- do.call(grid::radialGradient,
      c(list(colours = c("white", "#2673b8", "#173d61"), group = FALSE), case))
    grid::grid.rect(gp = grid::gpar(col = NA, fill = gradient))
  }
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    for (case in cases) draw(case)
  }, width = 4, height = 3, bg = "transparent", metrics = "systemfonts", standalone = TRUE)
  files <- compile_png(file, length(cases))
  points <- expand.grid(x = c(0.12, 0.28, 0.46, 0.54, 0.73, 0.88), y = c(0.26, 0.48, 0.71))
  for (i in seq_along(cases)) {
    reference <- native_gradient_png(function() draw(cases[[i]]))
    actual <- png::readPNG(files[i])
    difference <- abs(gradient_samples(actual, points$x, points$y) -
                      gradient_samples(reference, points$x, points$y))
    expect_lte(max(difference), 3, label = paste("radial case", i))
  }
})

test_that("shared gradient fills cover circles and compound paths with holes", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    gradient <- grid::linearGradient(c("red", "blue"), group = FALSE)
    grid::grid.circle(x = 0.25, y = 0.5, r = 0.2, gp = grid::gpar(fill = gradient, col = "black"))
    grid::grid.circle(x = 0.25, y = 0.5, r = 0.2, gp = grid::gpar(fill = gradient, col = "black"))
    grid::grid.polygon(x = c(0.55, 0.95, 0.75), y = c(0.2, 0.2, 0.8),
                       gp = grid::gpar(fill = gradient, col = "black"))
    grid::grid.path(x = c(0.1, 0.4, 0.4, 0.1, 0.2, 0.3, 0.3, 0.2),
                    y = c(0.1, 0.1, 0.4, 0.4, 0.2, 0.2, 0.3, 0.3),
                    id = rep(1:2, each = 4), rule = "evenodd",
                    gp = grid::gpar(fill = gradient, col = NA))
  }, width = 4, height = 3, bg = "transparent", metrics = "systemfonts", standalone = TRUE)
  source <- paste(readLines(file), collapse = "\n")
  definitions <- regmatches(source, gregexpr('<linearGradient id=', source, fixed = TRUE))[[1L]]
  expect_length(definitions, 3L)
  compile_svg(file)
  pixels <- png::readPNG(compile_png(file))
  expect_equal(pixels[163, 73, 4], 0)
  expect_equal(pixels[184, 44, 4], 1)
})

test_that("ggplot2 can request a vector gradient colour bar", {
  skip_if_not_installed("systemfonts")
  skip_if_not_installed("ggplot2")
  skip_if(getRversion() < "4.2.0", "Gradient capability reporting requires R 4.2")
  file <- tempfile(fileext = ".typ")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = disp)) +
    ggplot2::geom_point() +
    ggplot2::guides(colour = ggplot2::guide_colourbar(display = "gradient"))
  cetz_save(file, p, width = 5, height = 3, metrics = "systemfonts", standalone = TRUE)
  expect_length(embedded_pngs(file), 0L)
  expect_match(paste(readLines(file), collapse = "\n"), '<linearGradient id=', fixed = TRUE)
  compile_svg(file)
})

test_that("unsupported radial geometry fails clearly without leaving a device open", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  previous <- grDevices::dev.cur()
  expect_no_warning(expect_error(cetz_save(file, function() {
    grid::grid.newpage()
    grid::grid.rect(gp = grid::gpar(fill = grid::radialGradient(
      c("red", "blue"), cx1 = 0, cy1 = 0, r1 = 0, cx2 = 1, cy2 = 1, r2 = 0.1)))
  }, metrics = "systemfonts"), "circles must be nested"))
  expect_identical(grDevices::dev.cur(), previous)
})

test_that("a gradient callback error leaves a manually opened device usable", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  previous <- grDevices::dev.cur()
  device <- cetz(file, metrics = "systemfonts", standalone = TRUE)
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  grid::grid.newpage()
  expect_no_warning(expect_error(grid::grid.rect(gp = grid::gpar(
    fill = grid::radialGradient(c("red", "blue"), cx1 = 0, cy1 = 0, r1 = 0,
                               cx2 = 1, cy2 = 1, r2 = 0.1))),
    "circles must be nested"))
  expect_identical(grDevices::dev.cur(), device)
  expect_no_warning(grid::grid.rect(gp = grid::gpar(fill = "blue")))
  expect_no_warning(grDevices::dev.off(device))
  expect_identical(grDevices::dev.cur(), previous)
  compile_svg(file)
})

test_that("raw gradient elements follow affine CeTZ transforms", {
  skip_if_not_installed("systemfonts")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  draw <- function() {
    grid::grid.newpage()
    grid::grid.rect(gp = grid::gpar(col = "black", fill = grid::linearGradient(
      c("red", "blue"), x1 = 0, y1 = 0.5, x2 = 1, y2 = 0.5)))
  }
  directory <- tempfile("cetz-transform-gradient-")
  dir.create(directory)
  file <- file.path(directory, "figure.typ")
  with_device(file, draw, width = 4, height = 3, bg = "transparent", metrics = "systemfonts")
  document <- file.path(directory, "main.typ")
  writeLines(c(
    '#import "figure.typ": r-elements',
    sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
    '#set page(width: 500pt, height: 500pt, margin: 0pt, fill: none)',
    '#cetz.canvas(length: 1pt, {',
    '  import cetz.draw: *',
    '  hide(rect((0, 0), (500, 500), stroke: none), bounds: true)',
    '  floating(scope({ translate((150, 100)); rotate(30deg); scale(0.8)',
    '    r-elements(background: false)',
    '  }))',
    '})'
  ), document)
  actual <- png::readPNG(compile_png(document))
  reference <- native_gradient_png(draw)
  points <- expand.grid(x = c(0.25, 0.5, 0.75), y = c(0.25, 0.75))
  x <- points$x * 288
  y <- points$y * 216
  radians <- pi / 6
  transformed_x <- (150 + 0.8 * (x * cos(radians) - y * sin(radians))) / 500
  transformed_y <- (100 + 0.8 * (x * sin(radians) + y * cos(radians))) / 500
  difference <- abs(gradient_samples(actual, transformed_x, transformed_y) -
                    gradient_samples(reference, points$x, points$y))
  expect_lte(max(difference), 3)
})
