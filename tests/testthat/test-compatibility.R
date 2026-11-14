test_that("base layouts, logs, reversed axes, symbols and plotmath compile", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    graphics::par(mfrow = c(2, 2))
    plot(1:10, (1:10)^2, log = "xy")
    plot(1:10, xlim = c(11, 0), ylim = c(11, 0), type = "b")
    plot(0:25, pch = 0:25, col = 1:8)
    plot(1:5, main = expression(sum(x[i], i == 1, n)),
         xlab = expression(frac(alpha^2, beta)), ylab = expression(sqrt(x)))
    graphics::layout(matrix(c(1, 1, 2, 3), 2, byrow = TRUE))
    hist(iris$Sepal.Length)
    boxplot(iris$Sepal.Width)
    graphics::contour(volcano, drawlabels = TRUE)
  }, width = 8, height = 6, metrics = "systemfonts", standalone = TRUE)
  svg <- compile_svg(file)
  expect_true(file.exists(sub("-1.svg$", "-2.svg", svg)))
})

test_that("lattice trellis plots and patchwork compositions compile", {
  skip_if_not_installed("systemfonts")
  skip_if_not_installed("lattice")
  file <- tempfile(fileext = ".typ")
  cetz_save(file, lattice::xyplot(Sepal.Length ~ Sepal.Width | Species, data = iris),
            width = 7, height = 4, metrics = "systemfonts", standalone = TRUE)
  compile_svg(file)
  skip_if_not_installed("patchwork")
  skip_if_not_installed("ggplot2")
  a <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  b <- ggplot2::ggplot(mtcars, ggplot2::aes(factor(cyl))) + ggplot2::geom_bar()
  cetz_save(file, patchwork::wrap_plots(a, b), width = 7, height = 4,
            metrics = "systemfonts", standalone = TRUE)
  compile_svg(file)
})

test_that("device switching isolates annotation and resource state", {
  skip_if_not_installed("systemfonts")
  before <- grDevices::dev.cur()
  files <- c(tempfile(fileext = ".typ"), tempfile(fileext = ".typ"))
  a <- cetz(files[1], metrics = "systemfonts", standalone = TRUE)
  on.exit(if (a %in% grDevices::dev.list()) grDevices::dev.off(a), add = TRUE)
  plot(1:3)
  cetz_coord(2, 2, "same-name")
  b <- cetz(files[2], metrics = "systemfonts", standalone = TRUE)
  on.exit(if (b %in% grDevices::dev.list()) grDevices::dev.off(b), add = TRUE)
  plot(3:1)
  cetz_coord(2, 2, "same-name")
  grDevices::dev.set(a)
  cetz_node(2, 2, "device A")
  grDevices::dev.off(a)
  cetz_node(2, 2, "device B")
  grDevices::dev.off(b)
  expect_identical(grDevices::dev.cur(), before)
  compile_svg(files[1])
  compile_svg(files[2])
})

test_that("late output failures propagate through cetz_save and close the device", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-write-failure-")
  dir.create(directory)
  before <- grDevices::dev.cur()
  messages <- character()
  expect_error(withCallingHandlers(cetz_save(file.path(directory, "figure.typ"), function() {
    plot(1:3)
    unlink(directory, recursive = TRUE)
  }, metrics = "systemfonts"), warning = function(w) {
    messages <<- c(messages, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), "cannot open")
  expect_true(any(grepl("Could not write CeTZ output", messages, fixed = TRUE)))
  expect_identical(grDevices::dev.cur(), before)
})

test_that("persistent metrics survive a fresh R process", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  directory <- tempfile("cetz-process-cache-")
  dir.create(directory)
  file <- file.path(directory, "figure.typ")
  cache <- file.path(directory, "cache")
  with_device(file, function() {
    plot.new()
    strwidth("cross-process cache 123", units = "inches")
  }, cache_dir = cache)
  paths <- paste(vapply(.libPaths(), cetzDevice:::.str, character(1L)), collapse = ",")
  code <- paste0(
    '.libPaths(c(', paths, ')); ',
    'library(cetzDevice); cetz_clear_cache(); d <- cetz(', cetzDevice:::.str(file),
    ', cache_dir = ', cetzDevice:::.str(cache), ', typst = ',
    cetzDevice:::.str(unname(Sys.which("typst"))), '); plot.new(); ',
    'strwidth("cross-process cache 123", units="inches"); dev.off(d); ',
    'stopifnot(cetz_cache_info()$typst_calls == 0L)')
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("-e", shQuote(code)), stdout = TRUE, stderr = TRUE))
  expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
})

test_that("output failures remain recoverable when warnings are errors", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-warning-error-")
  dir.create(directory)
  before <- grDevices::dev.cur()
  old <- options(warn = 2)
  on.exit(options(old), add = TRUE)
  expect_error(cetz_save(file.path(directory, "figure.typ"), function() {
    plot(1:3)
    unlink(directory, recursive = TRUE)
  }, metrics = "systemfonts"), "Could not write CeTZ output")
  expect_identical(grDevices::dev.cur(), before)
})

test_that("vector interiors and transparency match R's native PNG device", {
  skip_if_not_installed("systemfonts")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  draw <- function() {
    graphics::par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
    graphics::plot.new()
    graphics::plot.window(xlim = c(0, 288), ylim = c(0, 216))
    graphics::rect(30, 30, 90, 90, col = "#2673b880", border = NA)
    graphics::points(140, 60, pch = 21, cex = 4, bg = "#d45d36")
    graphics::segments(30, 160, 240, 160, col = "#00aa00", lwd = 4, lend = "butt")
    graphics::polygon(c(190, 240, 215), c(30, 30, 90), col = "#9967a9", border = NA)
  }
  file <- tempfile(fileext = ".typ")
  with_device(file, draw, width = 4, height = 3, bg = "transparent",
              metrics = "systemfonts", standalone = TRUE)
  actual <- png::readPNG(compile_png(file))
  reference <- tempfile(fileext = ".png")
  grDevices::png(reference, width = 4, height = 3, units = "in", res = 72,
                  bg = "transparent", type = "cairo")
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  draw()
  grDevices::dev.off(device)
  expected <- png::readPNG(reference)
  indices <- cbind(216 - c(60, 60, 160, 60, 10) + 1L, c(60, 140, 100, 215, 10) + 1L)
  # Compare premultiplied colours: unpremultiplication can magnify the PNG
  # renderer's one-channel, eight-bit rounding error for semi-transparent fills.
  for (channel in 1:4) {
    a <- actual[, , channel][indices]
    b <- expected[, , channel][indices]
    if (channel < 4) {
      a <- a * actual[, , 4][indices]
      b <- b * expected[, , 4][indices]
    }
    expect_lte(max(abs(round(a * 255) - round(b * 255))), 1L)
  }
})

test_that("dash spacing scales with line width like R's Cairo device", {
  skip_if_not_installed("systemfonts")
  skip_if_not(capabilities("cairo"), "Cairo PNG device unavailable")
  draw <- function() {
    grid::grid.newpage()
    for (i in 1:6) grid::grid.lines(x = c(0.1, 0.9), y = i / 7,
      gp = grid::gpar(col = "blue", lwd = 2, lty = i, lineend = "butt"))
  }
  file <- tempfile(fileext = ".typ")
  with_device(file, draw, width = 4, height = 3, bg = "transparent",
              metrics = "systemfonts", standalone = TRUE)
  actual <- png::readPNG(compile_png(file))
  reference <- tempfile(fileext = ".png")
  grDevices::png(reference, width = 4, height = 3, units = "in", res = 72,
                  bg = "transparent", type = "cairo")
  device <- grDevices::dev.cur()
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  draw(); grDevices::dev.off(device)
  expected <- png::readPNG(reference)
  expand <- function(x) x | c(FALSE, x[-length(x)]) | c(x[-1L], FALSE)
  for (i in 1:6) {
    row <- floor(216 * (1 - i / 7)) + 1L
    a <- colSums(actual[seq.int(row - 2L, row + 2L), , 4L] > 0.1) > 0
    b <- colSums(expected[seq.int(row - 2L, row + 2L), , 4L] > 0.1) > 0
    expect_lte(sum(a & !expand(b)) + sum(b & !expand(a)), 2L)
  }
})
