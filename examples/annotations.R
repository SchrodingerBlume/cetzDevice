library(cetzDevice)
dir.create("output", showWarnings = FALSE)
cetz("output/annotations.typ", width = 5, height = 4, standalone = TRUE)
plot(1:5, (1:5)^2, pch = 19, col = "#2673b8", main = "R data + native CeTZ annotations")
cetz_coord(4, 16, "marked")
cetz_node(2.1, 20, cetz_latex("$y=x^2$"), name = "equation",
          options = 'frame: "rect", padding: 4, fill: rgb("#eef4fa")')
cetz_annotate('line("equation.east", "marked", stroke: rgb("#d45d36"), mark: (end: ">"))')
dev.off()

writeLines(c(
  '#import "annotations.typ": r-draw',
  sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
  '#set page(width: auto, height: auto, margin: 10pt)',
  '#cetz.canvas({',
  '  import cetz.draw: *',
  '  r-draw(name: "plot")',
  '  circle("plot.marked", radius: 0.12, stroke: red + 1pt)',
  '})'
), "output/embedded.typ")
