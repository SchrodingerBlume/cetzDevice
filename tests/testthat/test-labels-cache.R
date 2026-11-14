test_that("Typst and MiTeX labels are measured and rendered as native content", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  file <- tempfile(fileext = ".typ")
  with_device(file, function() {
    plot(1:4, xlab = cetz_typst("$alpha^2$"),
         ylab = cetz_latex("$\\frac{x}{\\sigma}$"))
    text(2, 3, cetz_typst("$integral_0^1 x dif x$"), srt = 25)
    text(3, 2, cetz_latex("$\\sum_{i=1}^n x_i$"))
    expect_gt(strwidth(cetz_typst("$alpha$"), units = "inches"), 0)
    expect_lt(strwidth(cetz_typst("$alpha$"), units = "inches"),
               strwidth("alpha", units = "inches"))
  }, width = 5, height = 4, standalone = TRUE)
  source <- paste(readLines(file), collapse = "\n")
  expect_match(source, '@preview/mitex:0.2.6', fixed = TRUE)
  expect_match(source, 'mode: "markup"', fixed = TRUE)
  expect_false(grepl("__cetz_typst__", source, fixed = TRUE))
  compile_svg(file)
})

test_that("global text modes and plotmath plain mode both compile", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  for (mode in c("typst", "latex")) {
    file <- tempfile(fileext = ".typ")
    label <- if (mode == "typst") "$alpha / beta$" else "$\\frac{\\alpha}{\\beta}$"
    with_device(file, function() plot(1:3, xlab = label),
                text_mode = mode, width = 4, height = 3, standalone = TRUE)
    compile_svg(file)
  }
  expect_error(cetz(metrics = "systemfonts", text_mode = "latex"), "require metrics")
})

test_that("markup preambles and relative imports are identical during measurement and rendering", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  directory <- tempfile("cetz-preamble-")
  dir.create(directory)
  writeLines('#let term = [Shared label]', file.path(directory, "shared.typ"))
  file <- file.path(directory, "figure.typ")
  preamble <- c('#import "shared.typ": term', '#let r-label-scope = (term: term)')
  with_device(file, function() plot(1:3, xlab = cetz_typst("#term")),
              preamble = preamble, width = 4, height = 3, standalone = TRUE)
  compile_svg(file)
  expect_length(list.files(directory, pattern = "^\\.cetz-measure", all.files = TRUE), 0L)
})

test_that("session and persistent caches reuse measurements and invalidate local imports", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  directory <- tempfile("cetz-cache-test-")
  dir.create(directory)
  cache <- file.path(directory, "cache")
  file <- file.path(directory, "figure.typ")
  cetz_clear_cache()
  draw <- function(persistent = TRUE) {
    d <- cetz(file, cache_dir = if (persistent) cache else NULL)
    plot.new()
    strwidth("persistent label 123", units = "inches")
    grDevices::dev.off(d)
  }
  draw(FALSE)
  memory_calls <- cetz_cache_info()$typst_calls
  draw()
  expect_identical(cetz_cache_info()$typst_calls, memory_calls)
  calls <- cetz_cache_info()$typst_calls
  expect_gt(calls, 0L)
  draw()
  expect_identical(cetz_cache_info()$typst_calls, calls)
  cetz_clear_cache()
  draw()
  expect_identical(cetz_cache_info()$typst_calls, 0L)
  expect_gt(cetz_cache_info()$hits, 0L)

  shared <- file.path(directory, "shared.typ")
  preamble <- c('#import "shared.typ": term', '#let r-label-scope = (term: term)')
  width <- function() {
    d <- cetz(file, preamble = preamble, cache_dir = cache)
    on.exit(grDevices::dev.off(d), add = TRUE)
    plot.new()
    strwidth(cetz_typst("#term"), units = "inches")
  }
  writeLines('#let term = [X]', shared)
  a <- width()
  writeLines('#let term = [XXXXXXXX]', shared)
  b <- width()
  expect_gt(b, a * 4)
  writeLines("keep", file.path(cache, "user-file.txt"))
  cetz_clear_cache(cache)
  expect_true(file.exists(file.path(cache, "user-file.txt")))
  expect_length(list.files(cache, pattern = "^cetz-metric-"), 0L)
})

test_that("invalid markup fails before a device is registered and cleans temporary files", {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  directory <- tempfile("cetz-invalid-")
  dir.create(directory)
  previous <- grDevices::dev.cur()
  expect_error(cetz(file.path(directory, "figure.typ"), preamble = "#let ="),
               "Typst text measurement failed")
  expect_identical(grDevices::dev.cur(), previous)
  expect_length(list.files(directory, all.files = TRUE, no.. = TRUE), 0L)
  expect_error(cetz_typst(NA_character_), "non-missing")
})
