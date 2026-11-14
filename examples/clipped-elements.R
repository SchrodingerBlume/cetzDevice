library(cetzDevice)
library(grid)
dir.create("output", showWarnings = FALSE)

cetz("output/clipped.typ", width = 5, height = 3.5, standalone = TRUE)
grid.newpage()
grid.rect(gp = gpar(fill = "#edf2f7", col = NA))
pushViewport(viewport(width = 0.7, height = 0.6, clip = "on"))
grid.circle(r = 0.75, gp = gpar(col = NA,
  fill = radialGradient(c("#e6b450", "#2673b8", "#173d61"))))
grid.lines(x = c(-0.2, 1.2), y = c(0.1, 0.9), gp = gpar(col = "#ffffff80", lwd = 12))
grid.text("Clipped CeTZ layers", x = 0.7, y = 0.75, gp = gpar(col = "white", fontsize = 18))
grid.raster(as.raster(matrix(c("#d45d36", "#e6b450", "#2673b8", "#70af95"), 2)),
            x = 0.95, y = 0.15, width = 0.5, height = 0.5, interpolate = FALSE)
grid.draw(cetz_coord_grob(0.5, 0.5, "panel-center", units = "npc"))
popViewport()
grid.text("r-elements(clip: true)", y = 0.08, gp = gpar(col = "#173d61"))
dev.off()

writeLines(c(
  '#import "clipped.typ": r-elements',
  sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
  '#set page(width: 360pt, height: 252pt, margin: 0pt, fill: none)',
  '#cetz.canvas(length: 1pt, { r-elements(clip: true) })'
), "output/clipped-elements.typ")
