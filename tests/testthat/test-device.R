test_that("base graphics export text, styles and real device operations", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot(1:4, c(1, 3, 2, 4), type = "b", pch = 21, bg = "#2070b080",
         main = 'Quotes " \\ # [] $', xlab = "x", ylab = "y")
    abline(0, 1, lty = 2, lwd = 2)
    text(2, 3, "rotated", srt = 35, adj = 0.3)
  }, width = 5, height = 4, metrics = "systemfonts", standalone = TRUE)
  source <- paste(readLines(file), collapse = "\n")
  expect_match(source, 'cetz.canvas', fixed = TRUE)
  expect_match(source, 'circle(', fixed = TRUE)
  expect_match(source, 'dash:', fixed = TRUE)
  expect_match(source, '#2070b080', fixed = TRUE)
  expect_match(source, 'anchor: "text"', fixed = TRUE)
  svg <- compile_svg(file)
  result <- paste(readLines(svg, warn = FALSE), collapse = "\n")
  expect_match(substr(result, 1L, 100L), 'width="360pt"', fixed = TRUE)
  expect_match(substr(result, 1L, 100L), 'height="288pt"', fixed = TRUE)
})

test_that("Typst measures fonts at the physical device scale", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot.new()
    a <- strwidth("Measurement", units = "inches", cex = 1)
    b <- strwidth("Measurement", units = "inches", cex = 2)
    expect_gt(a, 0)
    expect_equal(b / a, 2, tolerance = 1e-5)
    expect_gt(strheight("M", units = "inches"), 0)
    text(0.5, 0.5, "Measurement")
  }, width = 4, height = 3, standalone = TRUE)
  compile_svg(file)
})

test_that("multiple pages and compound paths survive export", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot.new()
    polypath(c(0.1, 0.9, 0.9, 0.1, NA, 0.3, 0.7, 0.7, 0.3),
             c(0.1, 0.1, 0.9, 0.9, NA, 0.3, 0.3, 0.7, 0.7),
             col = "#2070b0", rule = "evenodd")
    plot(1:3, main = "Second page")
  }, width = 4, height = 3, metrics = "systemfonts", standalone = TRUE)
  source <- paste(readLines(file), collapse = "\n")
  expect_match(source, 'fill-rule: "even-odd"', fixed = TRUE)
  svg <- compile_svg(file)
  expect_true(file.exists(sub("-1.svg$", "-2.svg", svg)))
})

test_that("grid viewport clipping keeps fixed bounds for overflowing content", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(width = 0.5, height = 0.5, clip = "on"))
    grid::grid.rect(width = 2, height = 2,
                    gp = grid::gpar(fill = "#2070b0", col = NA))
    grid::grid.text("Text across the boundary", x = 0.9,
                    gp = grid::gpar(col = "white"))
    grid::popViewport()
  }, width = 4, height = 2, metrics = "systemfonts", standalone = TRUE)
  svg <- paste(readLines(compile_svg(file), warn = FALSE), collapse = "\n")
  expect_match(substr(svg, 1L, 100L), 'viewBox="0 0 288 144"', fixed = TRUE)
  expect_match(substr(svg, 1L, 4000L), 'clip-path=', fixed = TRUE)
  pixels <- png::readPNG(compile_png(file))
  expect_equal(as.vector(pixels[72, 100, 1:3]), c(32, 112, 176) / 255)
  expect_equal(as.vector(pixels[72, 20, 1:3]), c(1, 1, 1))
})

test_that("Unicode and plotmath operations compile with Typst metrics", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot(1, main = expression(alpha^2 + frac(1, beta)),
         xlab = "Unicode: caf\u00e9 \u4e2d\u6587")
  }, width = 5, height = 4, standalone = TRUE)
  compile_svg(file)
})

test_that("a module imports into a Typst document", {
  skip_if_not_installed("systemfonts")
  dir <- tempfile("cetz-import-")
  dir.create(dir)
  file <- file.path(dir, "figure.typ")
  cetz_save(file, function() plot(1:3), width = 4, height = 3,
            metrics = "systemfonts")
  document <- file.path(dir, "main.typ")
  writeLines(c('#import "figure.typ": r-figure', '#r-figure()'), document)
  compile_svg(document)
})

test_that("transparent standalone pages do not acquire a white background", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::grid.rect(width = 0.5, height = 0.5,
                    gp = grid::gpar(fill = "#2070b080", col = NA))
  }, width = 2, height = 2, bg = "transparent", metrics = "systemfonts",
     standalone = TRUE)
  svg <- paste(readLines(compile_svg(file), warn = FALSE), collapse = "\n")
  expect_false(grepl('fill="#ffffff"', svg, fixed = TRUE))
  expect_match(svg, 'fill="#2070b080"', fixed = TRUE)
})

test_that("cetz_save restores the previous device when plotting fails", {
  skip_if_not_installed("systemfonts")
  old <- grDevices::dev.cur()
  file <- tempfile(fileext = ".typ")
  expect_error(cetz_save(file, function() stop("plot failed"), metrics = "systemfonts"),
               "plot failed")
  expect_identical(grDevices::dev.cur(), old)
  expect_true(file.exists(file))
})

test_that("ggplot2 facets, ribbons and legends compile", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg, colour = factor(cyl))) +
    ggplot2::geom_point() +
    ggplot2::geom_smooth(ggplot2::aes(group = 1), colour = "grey40",
                         method = "lm", se = TRUE) +
    ggplot2::facet_wrap(ggplot2::vars(am)) +
    ggplot2::theme_minimal()
  suppressMessages(cetz_save(file, p, width = 7, height = 4,
                             metrics = "systemfonts", standalone = TRUE))
  compile_svg(file)
})

test_that("invalid arguments fail before opening a device", {
  old <- grDevices::dev.cur()
  expect_error(cetz(width = -1), "positive finite")
  expect_error(cetz(height = NA_real_), "positive finite")
  expect_error(cetz(family = ""), "name a font")
  expect_error(cetz(typst = ""), "Typst CLI not found")
  expect_error(cetz(font_map = "Arial"), "named character")
  expect_identical(grDevices::dev.cur(), old)
})
