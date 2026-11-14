# Run from the repository root after R CMD INSTALL .
library(cetzDevice)
dir.create("output", showWarnings = FALSE)

# Raster and vector elements share the same drawing order and clipping region.
pixels <- as.raster(matrix(c("#2673b8", "#e6b450", "#d45d36",
                             "#70af9580", "#9967a9", "#2673b800"),
                           nrow = 2, byrow = TRUE))
cetz("output/raster.typ", width = 6, height = 4, standalone = TRUE)
par(mar = c(4.5, 4, 3, 1))
plot(NA, xlim = c(0, 10), ylim = c(0, 7), xlab = "x", ylab = "y",
     main = "Embedded raster + CeTZ annotations", xaxs = "i", yaxs = "i")
rasterImage(pixels, 0.5, 0.7, 4.5, 3.7, interpolate = FALSE)
rasterImage(pixels, 6.8, 1, 9.8, 3, angle = 35, interpolate = FALSE)
rect(0.5, 0.7, 4.5, 3.7, border = "#173d61", lwd = 1.5)
arrows(3.7, 5.6, 2.4, 3, col = "#173d61", lwd = 1.5, length = 0.1)
text(3.7, 6, "Vector annotations", col = "#173d61")
text(7.5, 5.8, "Rotation + alpha", col = "#173d61")
dev.off()

if (requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  data <- expand.grid(x = seq_len(nrow(volcano)), y = seq_len(ncol(volcano)))
  data$elevation <- as.vector(volcano)
  p <- ggplot(data, aes(x, y, fill = elevation)) +
    geom_raster() +
    scale_fill_viridis_c(name = "Elevation") +
    coord_equal(expand = FALSE) +
    labs(title = "R raster heatmap → CeTZ", x = "x", y = "y") +
    theme_minimal(base_family = "Arial")
  cetz_save("output/heatmap.typ", p, width = 6, height = 4, standalone = TRUE)
}
