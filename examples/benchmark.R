# Repeatable smoke benchmark; timings depend on hardware, fonts and Typst version.
library(cetzDevice)
dir.create("output", showWarnings = FALSE)
set.seed(1)
n <- as.integer(Sys.getenv("CETZ_BENCH_POINTS", "10000"))
x <- rnorm(n)
y <- x + rnorm(n)
elapsed <- system.time(cetz_save("output/benchmark-points.typ", function() {
  plot(x, y, pch = 16, cex = 0.35)
}, width = 6, height = 4, metrics = "systemfonts", standalone = TRUE))[["elapsed"]]
cat(sprintf("%d points: %.3fs export, %.1f KiB source\n", n, elapsed,
            file.info("output/benchmark-points.typ")$size / 1024))

if (nzchar(Sys.which("typst"))) {
  cetz_clear_cache()
  draw <- function() cetz_save("output/benchmark-labels.typ", function() {
    plot(1:10, xlab = cetz_latex("$\\alpha^2$"))
  }, width = 5, height = 4)
  cold <- system.time(draw())[["elapsed"]]
  calls <- cetz_cache_info()$typst_calls
  warm <- system.time(draw())[["elapsed"]]
  cat(sprintf("Labels: cold %.3fs (%d queries), warm %.3fs (%d new queries)\n",
              cold, calls, warm, cetz_cache_info()$typst_calls - calls))
}
