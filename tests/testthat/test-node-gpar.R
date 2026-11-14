test_that("grid nodes respect viewport rotation, alpha and scalar gpar recycling", {
  skip_if_not_installed("systemfonts")
  files <- c(tempfile(fileext = ".typ"), tempfile(fileext = ".typ"))
  gp <- grid::gpar(fontfamily = c(primary = "Arial"), fontsize = c(16, 30),
                    col = c("#2673b880", "red"), alpha = 0.4)
  for (i in 1:2) {
    with_device(files[i], function() {
      grid::grid.newpage()
      grid::pushViewport(grid::viewport(angle = 30))
      if (i == 1L) {
        grid::grid.text("TEST", x = 0.5, y = 0.5, rot = 15, gp = gp)
      } else {
        grid::grid.draw(cetz_node_grob(0.5, 0.5, "TEST", units = "npc", angle = 15, gp = gp))
      }
      grid::popViewport()
    }, width = 3, height = 2, bg = "transparent", metrics = "systemfonts", standalone = TRUE)
  }
  a <- png::readPNG(compile_png(files[1L]))
  b <- png::readPNG(compile_png(files[2L]))
  expect_equal(max(b[, , 4L]), max(a[, , 4L]), tolerance = 1 / 255)
  bounds <- function(image) {
    ink <- which(image[, , 4L] > 0.05, arr.ind = TRUE)
    c(range(ink[, 1L]), range(ink[, 2L]))
  }
  expect_lte(max(abs(bounds(a) - bounds(b))), 2)
})

test_that("transparent node labels retain their frames and numeric labels are accepted", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot.new()
    par(col = "transparent")
    cetz_node(108, 72, "Invisible", units = "device", name = "frame",
              options = 'frame: "rect", padding: 4, stroke: rgb("#ff0000")')
    par(col = "black")
    cetz_node(30, 30, 12.5, units = "device")
    expect_error(cetz_coord_grob(c(1, 2), 1, "bad"), "single units")
    expect_error(cetz_node_grob(c(1, 2), 1, "bad"), "single units")
  }, width = 3, height = 2, bg = "transparent", metrics = "systemfonts", standalone = TRUE)
  pixels <- png::readPNG(compile_png(file))
  expect_equal(pixels[72, 108, 4L], 0)
  expect_gt(sum(pixels[, , 1L] > 0.9 & pixels[, , 2L] < 0.1 & pixels[, , 4L] > 0.5), 10)
})

test_that("systemfonts fallback uses the same resolved family in Typst output", {
  skip_if_not_installed("systemfonts")
  requested <- "cetzDevice-nonexistent-font"
  resolved <- systemfonts::font_info(requested)$family[1L]
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::grid.text("Fallback font", gp = grid::gpar(fontfamily = requested))
  }, metrics = "systemfonts", standalone = TRUE)
  source <- paste(readLines(file), collapse = "\n")
  expect_match(source, paste0('font: "', resolved, '"'), fixed = TRUE)
  expect_false(grepl(requested, source, fixed = TRUE))
  compile_svg(file)
})
