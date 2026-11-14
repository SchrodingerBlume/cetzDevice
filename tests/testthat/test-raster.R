raster_fixture <- function() {
  matrix(c("#ff0000ff", "#00ff00ff", "#0000ffff",
           "#ffff00ff", "#00ffff80", "#ff00ff00"),
         nrow = 2, byrow = TRUE)
}

test_that("raster pixels, alpha and shared resources survive export", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  image <- raster_fixture()
  with_device(file, function() {
    expect_identical(unname(grDevices::dev.capabilities()$rasterImage), "yes")
    grid::grid.newpage()
    grid::grid.raster(image, width = 0.5, height = 0.5, interpolate = FALSE)
    grid::grid.raster(image, width = 0.2, height = 0.2, interpolate = TRUE)
    grid::grid.newpage()
    grid::grid.raster(image)
  }, width = 4, height = 3, metrics = "systemfonts", standalone = TRUE)
  embedded <- embedded_pngs(file)
  expect_length(embedded, 1L)
  decoded <- png::readPNG(embedded[[1L]])
  expected <- array(NA_real_, c(2, 3, 4))
  rgba <- grDevices::col2rgb(as.vector(image), alpha = TRUE) / 255
  for (channel in 1:4) expected[, , channel] <- matrix(rgba[channel, ], nrow = 2)
  expect_equal(decoded, expected)
  source <- paste(readLines(file), collapse = "\n")
  expect_match(source, 'scaling: "pixelated"', fixed = TRUE)
  expect_match(source, 'scaling: "smooth"', fixed = TRUE)
  svg <- compile_svg(file)
  result <- paste(readLines(svg, warn = FALSE), collapse = "\n")
  expect_match(result, "data:image/png;base64,", fixed = TRUE)
  expect_true(file.exists(sub("-1.svg$", "-2.svg", svg)))
  destination <- tempfile("cetz-raster-import-")
  dir.create(destination)
  expect_true(file.copy(file, file.path(destination, "figure.typ")))
  document <- file.path(destination, "main.typ")
  writeLines(c('#import "figure.typ": r-figure', '#r-figure()'), document)
  compile_svg(document)
})

test_that("native raster pixels with the NA_INTEGER bit pattern retain alpha", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::grid.raster(matrix("#00000080", 1, 1))
  }, metrics = "systemfonts")
  decoded <- png::readPNG(embedded_pngs(file)[[1L]])
  expect_equal(as.vector(decoded), c(0, 0, 0, 128 / 255))
})

test_that("rotated and reflected rasters match the native R PNG device", {
  skip_if_not_installed("systemfonts")
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  cases <- expand.grid(width = c(90, -90), height = c(60, -60), angle = c(0, 33, 90))
  cases <- rbind(cases, data.frame(width = 90, height = 2, angle = 0))
  image <- raster_fixture()
  draw <- function(case) {
    graphics::par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, 288), ylim = c(0, 216))
    graphics::rasterImage(image, 144, 108, 144 + case$width, 108 + case$height,
                          angle = case$angle, interpolate = FALSE)
  }
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    for (i in seq_len(nrow(cases))) draw(cases[i, ])
  }, width = 4, height = 3, bg = "transparent", metrics = "systemfonts",
     standalone = TRUE)
  files <- compile_png(file, nrow(cases))
  reference <- function(case) {
    path <- tempfile(fileext = ".png")
    grDevices::png(path, width = 4, height = 3, units = "in", res = 72,
                    bg = "transparent", type = "cairo")
    device <- grDevices::dev.cur()
    on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
    draw(case)
    grDevices::dev.off(device)
    png::readPNG(path)
  }
  for (i in seq_len(nrow(cases))) {
    case <- cases[i, ]
    positions <- expand.grid(row = 1:2, col = 1:3)
    u <- case$width * (positions$col - 0.5) / 3
    v <- case$height * (1 - (positions$row - 0.5) / 2)
    angle <- case$angle * pi / 180
    x <- 144 + u * cos(angle) - v * sin(angle)
    y <- 108 + u * sin(angle) + v * cos(angle)
    indices <- cbind(floor(216 - y) + 1L, floor(x) + 1L)
    sample_pixels <- function(pixels) {
      vapply(1:4, function(channel) pixels[, , channel][indices], numeric(nrow(indices)))
    }
    actual <- png::readPNG(files[i])
    expected <- reference(case)
    expect_equal(dim(actual), dim(expected))
    expect_equal(sample_pixels(actual), sample_pixels(expected), tolerance = 1 / 255,
                 info = paste("raster case", i, paste(case, collapse = ", ")))
  }
})

test_that("raster clipping and vector overlays preserve drawing order", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(width = 0.5, height = 0.5, clip = "on"))
    grid::grid.raster(matrix("#0000ff", 2, 2), width = 2, height = 2,
                      interpolate = FALSE)
    grid::grid.rect(width = 0.2, height = 0.2,
                    gp = grid::gpar(fill = "red", col = NA))
    grid::popViewport()
  }, width = 4, height = 2, bg = "transparent", metrics = "systemfonts",
     standalone = TRUE)
  actual <- png::readPNG(compile_png(file))
  expect_equal(actual[72, 144, ], c(1, 0, 0, 1))
  expect_equal(actual[72, 100, ], c(0, 0, 1, 1))
  expect_equal(actual[72, 20, 4], 0)
})

test_that("geom_raster and continuous raster colour bars compile", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  data <- expand.grid(x = 1:8, y = 1:6)
  data$value <- sin(data$x) + cos(data$y)
  p <- ggplot2::ggplot(data, ggplot2::aes(x, y, fill = value)) +
    ggplot2::geom_raster() +
    ggplot2::guides(fill = ggplot2::guide_colourbar(display = "raster")) +
    ggplot2::theme_minimal()
  cetz_save(file, p, width = 5, height = 3, metrics = "systemfonts", standalone = TRUE)
  expect_length(embedded_pngs(file), 2L)
  compile_svg(file)
  # Exercise ggplot2's default guide selection as well as an explicit raster guide.
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = disp)) +
    ggplot2::geom_point() + ggplot2::theme_minimal()
  cetz_save(file, p, width = 5, height = 3, metrics = "systemfonts", standalone = TRUE)
  expect_length(embedded_pngs(file), 1L)
  compile_svg(file)
})
