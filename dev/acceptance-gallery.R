# Regenerate only the review artefacts: Rscript dev/acceptance-gallery.R
acceptance_gallery <- function(results, out) {
  rgb_image <- function(path) {
    image <- png::readPNG(path)
    if (length(dim(image)) == 2L) image <- array(rep(image, 3), c(dim(image), 3L))
    if (dim(image)[3L] == 4L) for (i in 1:3)
      image[, , i] <- image[, , i] * image[, , 4] + 1 - image[, , 4]
    image[, , 1:3, drop = FALSE]
  }
  escape <- function(value) {
    value <- gsub("&", "&amp;", value, fixed = TRUE)
    value <- gsub("<", "&lt;", value, fixed = TRUE)
    gsub(">", "&gt;", value, fixed = TRUE)
  }
  html <- c('<!doctype html><meta charset="utf-8"><title>tikzDevice / cetzDevice acceptance</title>',
    '<style>body{font:15px sans-serif;margin:24px}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #ddd}img{width:432px}pre{white-space:pre-wrap}</style>',
    '<h1>tikzDevice / cetzDevice</h1><p>Same R inputs; fonts and TeX/Typst point units normalized. Image metrics are diagnostics, not compatibility percentages.</p>',
    '<table><tr><th>Case</th><th>tikzDevice / XeLaTeX</th><th>cetzDevice / Typst</th></tr>')
  for (i in seq_len(nrow(results))) {
    row <- results[i, ]
    for (engine in c("tikz", "cetz")) {
      error <- row[[paste0(engine, "_error")]]
      log <- file.path(out, engine, paste0(row$case, "-compile.log"))
      if (nzchar(error) && !file.exists(log)) writeLines(error, log)
    }
    reference <- if (row$tikz_ok) sprintf('<img src="tikz/%s-%d.png">', row$case, row$page) else
      paste0('<p>Reference unavailable</p><details><summary>Reference error</summary><pre>', escape(row$tikz_error), '</pre></details>')
    actual <- if (row$cetz_ok) sprintf('<img src="cetz/%s-%d.png">', row$case, row$page) else
      paste0('<p>Output unavailable</p><pre>', escape(row$cetz_error), '</pre>')
    html <- c(html, sprintf('<tr><td>%s, page %d<br>Unmatched coloured ink: %.4f<br>Page delta: %s px</td><td>%s</td><td>%s</td></tr>',
      row$case, row$page, row$unmatched_coloured, row$page_delta_px, reference, actual))
  }
  writeLines(c(html, '</table>'), file.path(out, "index.html"))
  for (sheet in seq_len(ceiling(nrow(results) / 8))) {
    selected <- seq.int((sheet - 1L) * 8L + 1L, min(sheet * 8L, nrow(results)))
    height <- length(selected) * 320 + 30
    grDevices::png(file.path(out, paste0("contact-", sheet, ".png")), width = 900, height = height, bg = "white")
    device <- grDevices::dev.cur()
    tryCatch({
      graphics::par(mar = rep(0, 4), xaxs = "i", yaxs = "i")
      graphics::plot.new(); graphics::plot.window(c(0, 900), c(0, height))
      for (j in seq_along(selected)) {
        row <- results[selected[j], ]
        top <- height - 30 - (j - 1L) * 320
        graphics::text(10, top + 10, paste(row$case, "page", row$page), adj = 0, cex = 0.8)
        for (engine in c("tikz", "cetz")) {
          image <- file.path(out, engine, paste0(row$case, "-", row$page, ".png"))
          left <- if (engine == "tikz") 10 else 458
          if (file.exists(image)) {
            graphics::rasterImage(grDevices::as.raster(rgb_image(image)), left, top - 288,
                                  left + 432, top, interpolate = TRUE)
          } else graphics::text(left + 216, top - 144,
            if (engine == "tikz") "Reference unavailable" else "Output unavailable", col = "gray50")
        }
      }
    }, finally = grDevices::dev.off(device))
  }
  invisible(NULL)
}

if (sys.nframe() == 0L) {
  out <- Sys.getenv("CETZ_ACCEPTANCE_OUTPUT", "output/acceptance")
  acceptance_gallery(utils::read.csv(file.path(out, "results.csv")), out)
}
