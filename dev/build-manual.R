library(knitr)

root <- normalizePath(".")
stopifnot(file.exists(file.path(root, "vignettes", "cetzDevice.Rnw")))
out <- file.path(root, "output", "manual")
dir.create(out, recursive = TRUE, showWarnings = FALSE)

options(cetzDevice.build_figures = TRUE)
knit(file.path(root, "vignettes", "cetzDevice.Rnw"),
     output = file.path(out, "cetzDevice.tex"), quiet = TRUE)

Sys.setenv(TEXINPUTS = paste0(file.path(root, "vignettes"), "//:",
                             Sys.getenv("TEXINPUTS")))
setwd(out)
status <- system2("latexmk", c("-pdf", "-interaction=nonstopmode",
                             "-halt-on-error", "cetzDevice.tex"),
                  stdout = "build.log", stderr = "build.log")
setwd(root)
if (status != 0L) stop("Manual build failed; see output/manual/build.log")
file.copy(file.path(out, "cetzDevice.pdf"),
          file.path(root, "docs", "cetzDevice.pdf"), overwrite = TRUE)
tools::compactPDF(file.path(root, "docs", "cetzDevice.pdf"), gs_quality = "ebook")
