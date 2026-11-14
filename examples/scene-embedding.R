library(cetzDevice)
dir.create("output", showWarnings = FALSE)
cetz("output/scene.typ", width = 5, height = 3.5, standalone = TRUE)
plot(1:5, (1:5)^2, type = "b", pch = 19, col = "#2673b8", xlab = "x", ylab = "y")
lines(1:5, (1:5)^2, col = "#2673b8")
cetz_coord(4, 16, "target")
cetz_node(2.2, 19, cetz_latex("$y=x^2$"), name = "note", clip = TRUE,
          options = 'frame: "rect", padding: 4, fill: rgb("#edf2f7")')
cetz_annotate('circle("target", radius: 3, name: "sample", stroke: rgb("#d45d36"))', clip = TRUE)
mtext("Shared names across clipping layers", side = 3, line = 1)
cetz_annotate('line("note.east", "sample.west", stroke: rgb("#d45d36"), mark: (end: ">"))')
dev.off()

writeLines(c(
  '#import "scene.typ": r-draw',
  sprintf('#import "@preview/cetz:%s" as cetz', cetz_backend()$cetz),
  '#set page(width: auto, height: auto, margin: 10pt)',
  '#cetz.canvas({',
  '  import cetz.draw: *',
  '  group({',
  '    rotate(12deg); scale(x: 0.85, y: 1.05)',
  '    r-draw(name: "plot")',
  '    circle("plot.note.north", radius: 0.1, stroke: red)',
  '  })',
  '})'
), "output/scene-embedding.typ")
