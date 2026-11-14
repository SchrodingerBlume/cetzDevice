test_that("base annotations share named coordinates across clipping changes", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot(1:5, (1:5)^2)
    xy <- cetz_coord(4, 16, "marked")
    expect_equal(unname(xy), c(graphics::grconvertX(4, "user", "device"),
                              graphics::grconvertY(16, "user", "device")))
    cetz_node(2, 20, "Annotation", name = "label", options = 'frame: "rect", padding: 2')
    cetz_annotate('line("marked", "label.south", stroke: red, mark: (end: ">"))')
    expect_error(cetz_coord(2, 2, "marked"), "Duplicate coordinate")
  }, width = 5, height = 4, metrics = "systemfonts", standalone = TRUE)
  compile_svg(file)
  directory <- dirname(file)
  document <- tempfile("cetz-embed-", tmpdir = directory, fileext = ".typ")
  writeLines(c(
    paste0('#import "', basename(file), '": r-draw, r-elements'),
    sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
    '#set page(width: auto, height: auto, margin: 5pt)',
    '#cetz.canvas({',
    '  import cetz.draw: *',
    '  r-draw(origin: (1, 0), angle: 12deg, name: "plot")',
    '  circle("plot.marked", radius: 0.1, stroke: red)',
    '})',
    '#pagebreak()',
    '#cetz.canvas(length: 1pt, {',
    '  import cetz.draw: *',
    '  r-elements()',
    '  circle("marked", radius: 5, stroke: red)',
    '})'
  ), document)
  svg <- compile_svg(document)
  expect_true(file.exists(sub("-1.svg$", "-2.svg", svg)))
})

test_that("grid annotation grobs convert viewport positions and support native math nodes", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(xscale = c(0, 10), yscale = c(0, 20)))
    grid::grid.draw(cetz_coord_grob(5, 10, "middle"))
    grid::grid.draw(cetz_node_grob(8, 15, cetz_latex("$\\alpha^2$"),
                                   name = "formula", gp = grid::gpar(col = "blue")))
    grid::grid.draw(cetz_annotate_grob('line("middle", "formula", stroke: blue)'))
    grid::popViewport()
  }, width = 4, height = 3, standalone = TRUE)
  compile_svg(file)
  expect_error(cetz_annotate("line((0,0),(1,1))"), "active device")
})

test_that("multiple output files, console mode, foreground and line width options work", {
  skip_if_not_installed("systemfonts")
  directory <- tempfile("cetz-pages-")
  dir.create(directory)
  pattern <- file.path(directory, "figure-%03d.typ")
  with_device(pattern, function() {
    plot(1:3)
    plot(3:1)
  }, onefile = FALSE, fg = "red", lwd_unit = 0.4, metrics = "systemfonts", standalone = TRUE)
  expect_true(file.exists(file.path(directory, "figure-001.typ")))
  expect_true(file.exists(file.path(directory, "figure-002.typ")))
  source <- paste(readLines(file.path(directory, "figure-001.typ")), collapse = "\n")
  expect_match(source, '#ff0000ff', fixed = TRUE)
  expect_match(source, 'thickness: 0.4pt', fixed = TRUE)
  compile_svg(file.path(directory, "figure-002.typ"))
  lines <- capture.output(with_device("", function() plot(1:3), metrics = "systemfonts"))
  expect_true(any(grepl("#let r-layers", lines, fixed = TRUE)))
  expect_error(cetz("figure.typ", onefile = FALSE), "placeholder")
})
