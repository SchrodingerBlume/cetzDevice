test_that("r-elements opt-in clipping matches r-figure for paths, strokes, text and images", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-clip-elements-")
  dir.create(directory)
  file <- file.path(directory, "figure.typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(width = 0.5, height = 0.5, clip = "on"))
    grid::grid.raster(matrix("blue", 2, 2), width = 1.6, height = 1.6, interpolate = FALSE)
    grid::grid.lines(x = c(-0.2, 1.2), y = 0.15, gp = grid::gpar(col = "red", lwd = 8))
    grid::grid.text("Overflow", x = 0.95, y = 0.7, gp = grid::gpar(col = "white"))
    grid::grid.draw(cetz_coord_grob(0.5, 0.5, "registered", units = "npc"))
    grid::popViewport()
  }, width = 4, height = 2, bg = "transparent", metrics = "systemfonts")
  document <- file.path(directory, "main.typ")
  writeLines(c(
    '#import "figure.typ": r-figure, r-elements',
    sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
    '#set page(width: 288pt, height: 144pt, margin: 0pt, fill: none)',
    '#set par(leading: 0pt, spacing: 0pt)',
    '#r-figure()',
    '#pagebreak()',
    '#cetz.canvas(length: 1pt, {',
    '  r-elements(clip: true)',
    '  cetz.draw.hide(cetz.draw.circle("registered", radius: 1))',
    '})',
    '#pagebreak()',
    '#cetz.canvas(length: 1pt, { r-elements() })'
  ), document)
  files <- compile_png(document, 3L)
  reference <- png::readPNG(files[1L])
  clipped <- png::readPNG(files[2L])
  raw <- png::readPNG(files[3L])
  expect_equal(dim(clipped), dim(reference))
  expect_equal(clipped, reference, tolerance = 1 / 255)
  expect_equal(clipped[72, 50, 4], 0)
  expect_equal(raw[72, 50, 4], 1)
  expect_equal(clipped[72, 100, ], c(0, 0, 1, 1))
})
