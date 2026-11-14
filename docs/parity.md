Feature Comparison with tikzDevice
==================================

cetzDevice provides a Typst/CeTZ graphics device using tikzDevice as its
reference for graphics output, typesetter-based measurement, and annotations.
This comparison describes cetzDevice 0.5.3.1, targeting CeTZ 0.5.3 and
Typst 0.15.0 or later. `cetz_backend()` reports the exact mapping.


Graphics and Output
-------------------

| tikzDevice facility | cetzDevice equivalent |
|---|---|
| Open, draw, and close a graphics device | `cetz()` and `dev.off()` |
| Lines, shapes, and compound paths | Graphics engine callbacks |
| Text, rotation, alignment, alpha, and line styles | CeTZ paths and Typst content |
| Typesetter-based font metrics | Typst queries and baseline probes |
| LaTeX labels | `cetz_latex()` or `text_mode = "latex"`, using MiTeX 0.2.6 |
| Native typesetting commands | `cetz_typst()` or `text_mode = "typst"` |
| Shared document definitions | `preamble` and `r-label-scope` |
| Rectangular clipping | Typst clipping containers around CeTZ layers |
| Raster output | Embedded PNG data, shared across pages |
| Native annotations, nodes, and coordinates | `cetz_annotate()`, `cetz_node()`, and `cetz_coord()` |
| Grid annotations | `cetz_*_grob()` constructors |
| Figure chunks and stand-alone documents | `r-figure()` and `standalone = TRUE` |
| Embedding in another drawing | `r-draw()` |
| Bare drawing commands | `r-elements()`, optionally with `clip: true` |
| Separate files for multiple pages | `onefile = FALSE` and a `%03d` filename |
| Console output | `console = TRUE` or an empty filename |
| Font metric dictionary | Session cache and optional `cache_dir` |
| Shared style definitions | Repeated strokes stored in `r-strokes` |

Linear gradients and nested-circle radial gradients are also supported.
Their fills are embedded as SVG vectors. Tiling patterns, masks,
nonrectangular clipping paths, glyph runs, and advanced compositing are
not implemented.


Differences
-----------

MiTeX interprets a subset of LaTeX. It does not execute arbitrary LaTeX
packages, macros, or TikZ drawings. R's `expression()` labels retain the
plotmath layout produced by the R graphics engine.

`r-draw()` retains clipping and physical dimensions. `r-elements()` returns
raw CeTZ elements by default, or clipped layers when `clip: true` is used.
These functions serve the embedding use cases of tikzDevice's `bareBones`
mode. They use CeTZ's canvas and content semantics.

Named coordinates, nodes, and shapes remain available across clipping
layers. Clipped embedding applies affine transformations to the complete
plot and its anchors. Unclipped elements follow CeTZ's native rules for
content and physical stroke widths.

Gradient fills retain device-space endpoints, color stops, alpha, and
extension modes. Radial circles must be nested and have different radii.
The outlines remain CeTZ paths.

Font families are recorded explicitly. The machine that compiles a figure
needs the fonts used to measure it. Changes to fonts or dimensions require
the R plot to be exported again if its layout is to change.

Drawing operations pass from C callbacks to R for recording. The device
does not use native bulk collection or streaming output.


Testing
-------

The test suite covers base graphics, grid, ggplot2, lattice, and patchwork.
It includes multiple panels, log and reversed coordinates, plotmath,
facets, legends, confidence intervals, raster color bars, and heat maps.

Rendering checks compile Typst output and compare dimensions and pixel
samples with R's Cairo PNG device. Raster and gradient tests cover alpha,
rotation, reflection, clipping, extension modes, nested radial geometry,
and affine embedding. Device tests cover drawing and output errors,
device switching, and cache reuse across devices and R processes.

The [CI workflow][ci] checks Ubuntu, macOS, and Windows with Typst 0.15.0
and latest. It also checks R-devel, R-oldrel, and an installation without
Typst. Package checks use `R CMD check --as-cran`, including the reference
manual and vignette rebuild.

The paired tikzDevice/XeLaTeX and cetzDevice/Typst figures are described in
the [rendering comparison](acceptance.md). Rebuild them with:

```sh
Rscript dev/compare-tikz.R
```

[ci]: https://github.com/SchrodingerBlume/cetzDevice/actions/workflows/check.yaml
