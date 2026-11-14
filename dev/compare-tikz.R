# Run from the repository root after R CMD INSTALL .
# Optional: CETZ_ACCEPTANCE_CASES=hello,legend Rscript dev/compare-tikz.R
library(cetzDevice)
stopifnot(requireNamespace("tikzDevice", quietly = TRUE), requireNamespace("png", quietly = TRUE))
tools <- Sys.which(c("xelatex", "pdftoppm", "typst"))
if (any(!nzchar(tools))) stop("Install XeLaTeX, pdftoppm and Typst before running the comparison")
source(system.file("validation", "cases.R", package = "cetzDevice"))
cases <- acceptance_cases()
selection <- Sys.getenv("CETZ_ACCEPTANCE_CASES")
if (nzchar(selection)) cases <- Filter(function(x) x$id %in% strsplit(selection, ",", fixed = TRUE)[[1L]], cases)
if (!length(cases)) stop("No matching acceptance cases")
out <- Sys.getenv("CETZ_ACCEPTANCE_OUTPUT", "output/acceptance")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
out <- normalizePath(out)
for (directory in c("tikz", "cetz", "cache")) dir.create(file.path(out, directory), showWarnings = FALSE)
options(tikzMetricsDictionary = file.path(out, "tikz-metrics-unicode-12pt"),
        tikzDocumentDeclaration = "\\documentclass[12pt]{article}",
        tikzUnicodeMetricPackages = "\\usetikzlibrary{calc}")
jsonlite::write_json(list(
  R = R.version.string, platform = R.version$platform,
  cetzDevice = as.character(packageVersion("cetzDevice")),
  tikzDevice = as.character(packageVersion("tikzDevice")), backend = cetz_backend(),
  typst = system2(tools[["typst"]], "--version", stdout = TRUE),
  ppi = as.integer(Sys.getenv("CETZ_ACCEPTANCE_PPI", "144")),
  tikz_pointsize = 12, cetz_pointsize = 12 * 72/72.27,
  note = "TeX point units normalized; fontenc omitted from XeLaTeX metric preamble to retain Unicode fontspec encoding."
), file.path(out, "environment.json"), auto_unbox = TRUE, pretty = TRUE)
ppi <- as.integer(Sys.getenv("CETZ_ACCEPTANCE_PPI", "144"))
with_directory <- function(directory, action) {
  old <- getwd(); on.exit(setwd(old), add = TRUE)
  setwd(directory); action()
}
run <- function(executable, args, log, directory = NULL) {
  action <- function() suppressWarnings(system2(executable, args, stdout = log, stderr = log, timeout = 120))
  status <- if (is.null(directory)) action() else with_directory(directory, action)
  if (status != 0L) stop(paste(readLines(log, warn = FALSE), collapse = "\n"))
}
context <- function(engine, family) {
  if (engine == "tikz") list(
    family = family, math = identity,
    coord = function(x, y, name) tikzDevice::tikzCoord(x, y, name),
    node = function(x, y, value, name, clip) tikzDevice::tikzNode(x, y, name = name,
      content = value, opts = "draw,rectangle,inner sep=3bp,line width=0.75bp"),
    link = function(from, to) tikzDevice::tikzAnnotate(sprintf("\\draw[red,line width=0.75bp,->] (%s) -- (%s);", from, to)),
    segment = function(from, to) tikzDevice::tikzAnnotate(sprintf("\\draw[red,line width=0.75bp] (%s) -- (%s);", from, to)),
    grid_node = function(x, y, value, name, clip) tikzDevice::grid.tikzNode(x, y, name = name,
      content = value, opts = "draw,rectangle,inner sep=3bp,line width=0.75bp"),
    grid_link = function(name) tikzDevice::grid.tikzAnnotate(sprintf("\\draw[red,line width=0.75bp,->] (%s) -- (300bp,200bp);", name))
  ) else list(
    family = family, math = cetz_latex,
    coord = cetz_coord,
    node = function(x, y, value, name, clip) cetz_node(x, y, value, name = name,
      clip = clip, options = 'frame: "rect", padding: 3, stroke: 0.75pt'),
    link = function(from, to) cetz_annotate(sprintf('line("%s", "%s", stroke: rgb("#ff0000") + 0.75pt, mark: (end: ">"))', from, to)),
    segment = function(from, to) cetz_annotate(sprintf('line("%s", "%s", stroke: rgb("#ff0000") + 0.75pt)', from, to)),
    grid_node = function(x, y, value, name, clip) grid::grid.draw(cetz_node_grob(x, y, value,
      name = name, clip = clip, options = 'frame: "rect", padding: 3, stroke: 0.75pt')),
    grid_link = function(name) grid::grid.draw(cetz_annotate_grob(sprintf(
      'line("%s", (300,200), stroke: rgb("#ff0000") + 0.75pt, mark: (end: ">"))', name)))
  )
}

render <- function(case, engine) {
  directory <- file.path(out, engine)
  file <- paste0(case$id, if (engine == "tikz") ".tex" else ".typ")
  log <- file.path(directory, paste0(case$id, "-compile.log"))
  stale <- list.files(directory, pattern = paste0("^", case$id, "-[0-9]+\\.png$"), full.names = TRUE)
  unlink(c(stale, log, paste0(log, ".png"), file.path(directory, file),
           if (engine == "tikz") file.path(directory, paste0(case$id, ".pdf"))))
  warnings <- character()
  result <- tryCatch(withCallingHandlers({
    with_directory(directory, function() {
      if (engine == "tikz") {
        packages <- c("\\usepackage{fontspec}", "\\usepackage{tikz}", "\\usepackage{xcolor}",
          sprintf("\\setmainfont[Ligatures=NoCommon]{%s}", case$family),
          "\\usepackage[active,tightpage,xetex]{preview}",
          "\\PreviewEnvironment{pgfpicture}", "\\setlength\\PreviewBorder{0pt}")
        tikzDevice::tikz(file, width = 6, height = 4, standAlone = TRUE, engine = "xetex",
          documentDeclaration = "\\documentclass[12pt]{article}", packages = packages,
          bg = "white", lwdUnit = 72.27/96, timestamp = FALSE)
      } else {
        cetz(file, width = 6, height = 4, pointsize = 12 * 72/72.27,
          family = case$family, standalone = TRUE, cache_dir = file.path(out, "cache"))
      }
      device <- grDevices::dev.cur()
      on.exit(if (device %in% grDevices::dev.list()) grDevices::dev.off(device), add = TRUE)
      set.seed(4)
      case$draw(context(engine, case$family))
      grDevices::dev.off(device)
    })
    if (engine == "tikz") {
      run(tools[["xelatex"]], c("-interaction=nonstopmode", "-halt-on-error", shQuote(file)), log, directory)
      run(tools[["pdftoppm"]], c("-png", "-r", as.character(ppi),
        shQuote(sub("\\.tex$", ".pdf", file.path(directory, file))),
        shQuote(file.path(directory, case$id))), paste0(log, ".png"))
    } else {
      run(tools[["typst"]], c("compile", shQuote(file.path(directory, file)),
        shQuote(file.path(directory, paste0(case$id, "-{p}.png"))), "--ppi", as.character(ppi)), log)
    }
    diagnostics <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
    warnings <- c(warnings, diagnostics[grepl("Missing character:|^warning:|Font Warning|fontspec Warning", diagnostics)])
    pages <- list.files(directory, pattern = paste0("^", case$id, "-[0-9]+\\.png$"))
    if (length(pages) != case$pages) stop("Expected ", case$pages, " pages; found ", length(pages))
    list(ok = TRUE, error = "")
  }, warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w)); invokeRestart("muffleWarning")
  }), error = function(e) list(ok = FALSE, error = conditionMessage(e)))
  result$warnings <- paste(unique(warnings), collapse = " | ")
  result
}

rgb_image <- function(path) {
  image <- png::readPNG(path)
  if (length(dim(image)) == 2L) image <- array(rep(image, 3), c(dim(image), 3L))
  if (dim(image)[3L] == 4L) {
    for (i in 1:3) image[, , i] <- image[, , i] * image[, , 4] + 1 - image[, , 4]
  }
  image[, , 1:3, drop = FALSE]
}
dilate <- function(mask, radius = 2L) {
  result <- mask
  nr <- nrow(mask); nc <- ncol(mask)
  for (dy in -radius:radius) for (dx in -radius:radius) {
    rows <- seq.int(max(1L, 1L + dy), min(nr, nr + dy))
    cols <- seq.int(max(1L, 1L + dx), min(nc, nc + dx))
    result[rows, cols] <- result[rows, cols] | mask[rows - dy, cols - dx]
  }
  result
}
compare <- function(reference, actual) {
  a <- rgb_image(reference); b <- rgb_image(actual)
  page_delta <- max(abs(dim(a)[1:2] - dim(b)[1:2]))
  size <- pmax(dim(a)[1:2], dim(b)[1:2])
  pad <- function(image) {
    result <- array(1, c(size, 3L)); result[seq_len(dim(image)[1]), seq_len(dim(image)[2]), ] <- image; result
  }
  a <- pad(a); b <- pad(b)
  colour <- function(image) {
    high <- pmax(image[, , 1], image[, , 2], image[, , 3])
    low <- pmin(image[, , 1], image[, , 2], image[, , 3])
    high - low > 0.2 & low < 0.85
  }
  am <- colour(a); bm <- colour(b)
  unmatched <- (sum(am & !dilate(bm)) + sum(bm & !dilate(am))) / max(1, sum(am) + sum(bm))
  list(page_delta = page_delta, coloured_pixels = sum(am) + sum(bm),
       unmatched = unmatched, rgb_mae = mean(abs(a - b)))
}

rows <- list()
for (case in cases) {
  cat("Comparing", case$id, "\n")
  reference <- render(case, "tikz")
  actual <- render(case, "cetz")
  for (page in seq_len(case$pages)) {
    images <- file.path(out, c("tikz", "cetz"), paste0(case$id, "-", page, ".png"))
    metric <- if (reference$ok && actual$ok && all(file.exists(images))) compare(images[1], images[2]) else
      list(page_delta = NA_real_, coloured_pixels = NA_real_, unmatched = NA_real_, rgb_mae = NA_real_)
    rows[[length(rows) + 1L]] <- data.frame(case = case$id, page = page, source = case$source,
      tikz_ok = reference$ok, cetz_ok = actual$ok, page_delta_px = metric$page_delta,
      coloured_pixels = metric$coloured_pixels, unmatched_coloured = metric$unmatched,
      rgb_mae = metric$rgb_mae, tikz_warnings = reference$warnings, cetz_warnings = actual$warnings,
      tikz_error = reference$error, cetz_error = actual$error,
      reference_limit = !reference$ok && !is.null(case$reference_error) &&
        grepl(case$reference_error, reference$error, fixed = TRUE))
  }
  utils::write.csv(do.call(rbind, rows), file.path(out, "results.csv"), row.names = FALSE)
}
results <- do.call(rbind, rows)
comparable <- with(results, tikz_ok & cetz_ok)
results$geometry_pass <- ifelse(comparable, with(results, page_delta_px <= 1 &
  coloured_pixels > 0 & unmatched_coloured <= 0.03), NA)
results$warning_free <- with(results, !nzchar(tikz_warnings) & !nzchar(cetz_warnings))
results$acceptance_pass <- with(results, cetz_ok & !nzchar(cetz_warnings) &
  ((comparable & geometry_pass & !nzchar(tikz_warnings)) | reference_limit))
utils::write.csv(results, file.path(out, "results.csv"), row.names = FALSE)
maximum <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
jsonlite::write_json(list(
  scenarios = length(cases), pages = nrow(results),
  rendered_by_both = sum(results$tikz_ok & results$cetz_ok),
  cetz_rendered_pages = sum(results$cetz_ok),
  reference_limit_pages = sum(results$reference_limit),
  geometry_pass = sum(results$geometry_pass, na.rm = TRUE),
  warning_free = sum(results$warning_free),
  max_page_delta_px = maximum(results$page_delta_px),
  max_unmatched_coloured = maximum(results$unmatched_coloured),
  criteria = list(page_delta_px = 1, coloured_ink_dilation_px = 2,
                  max_unmatched_coloured = 0.03),
  note = "These are per-fixture geometry checks, not a compatibility percentage; inspect the paired gallery for text and rendering differences."
), file.path(out, "summary.json"), auto_unbox = TRUE, pretty = TRUE)
source("dev/acceptance-gallery.R")
acceptance_gallery(results, out)
print(results[, c("case", "page", "tikz_ok", "cetz_ok", "page_delta_px", "unmatched_coloured")], row.names = FALSE)
if (anyNA(results$acceptance_pass) || !all(results$acceptance_pass))
  stop("Acceptance needs review; inspect results.csv, compiler logs and index.html")
