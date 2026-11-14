compile_svg <- function(file) {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  output <- sub("\\.typ$", "-{p}.svg", file)
  errors <- tempfile()
  on.exit(unlink(errors), add = TRUE)
  status <- system2(Sys.which("typst"), c("compile", shQuote(file), shQuote(output), "--jobs", "2"),
                    stdout = errors, stderr = errors)
  expect_equal(status, 0L, info = paste(readLines(errors, warn = FALSE), collapse = "\n"))
  if (status != 0L) stop("Typst compilation failed")
  sub("\\.typ$", "-1.svg", file)
}

with_device <- function(file, draw, ...) {
  device <- cetz(file, ...)
  on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
  draw()
  grDevices::dev.off(device)
  invisible(file)
}

compile_png <- function(file, pages = 1L) {
  skip_if(Sys.which("typst") == "", "Typst CLI unavailable")
  output <- sub("\\.typ$", "-{p}.png", file)
  errors <- tempfile()
  on.exit(unlink(errors), add = TRUE)
  status <- system2(Sys.which("typst"),
    c("compile", shQuote(file), shQuote(output), "--ppi", "72", "--jobs", "2"),
    stdout = errors, stderr = errors)
  expect_equal(status, 0L, info = paste(readLines(errors, warn = FALSE), collapse = "\n"))
  if (status != 0L) stop("Typst compilation failed")
  vapply(seq_len(pages), function(page) {
    sub("\\.typ$", paste0("-", page, ".png"), file)
  }, character(1L))
}

embedded_pngs <- function(file) {
  source <- paste(readLines(file), collapse = "\n")
  blocks <- regmatches(source,
    gregexpr("bytes\\(\\([[:space:][:digit:],]+\\)\\)", source))[[1L]]
  lapply(blocks, function(block) {
    as.raw(as.integer(strsplit(gsub("[^0-9,]", "", block), ",", fixed = TRUE)[[1L]]))
  })
}
