test_that("package versions identify the exact CeTZ version and device revision", {
  backend <- cetz_backend()
  metadata <- utils::packageDescription("cetzDevice")
  version <- strsplit(metadata$Version, ".", fixed = TRUE)[[1L]]
  expect_length(version, 4L)
  expect_identical(paste(version[1:3], collapse = "."), backend$cetz)
  expect_gt(as.integer(version[4L]), 0L)
  expect_identical(metadata[["Config/cetzDevice/CeTZ"]], backend$cetz)
  expect_identical(metadata[["Config/cetzDevice/Typst"]], backend$typst_min)
})

test_that("exports pin the declared CeTZ version", {
  skip_if_not_installed("systemfonts")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() plot(1:3), metrics = "systemfonts", standalone = TRUE)
  source <- readLines(file)
  expected <- sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz)
  expect_true(expected %in% source)
  compile_svg(file)
})

test_that("an older Typst compiler is rejected before registering a device", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  previous <- grDevices::dev.cur()
  local_mocked_bindings(.typst_version = function(executable) "typst 0.14.2", .package = "cetzDevice")
  expect_error(cetz(tempfile(fileext = ".typ")), "requires Typst >= 0.15.0", fixed = TRUE)
  expect_identical(grDevices::dev.cur(), previous)
})
