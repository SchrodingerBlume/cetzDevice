Rendering Comparison with tikzDevice
====================================

This comparison was recorded during development of cetzDevice 0.5.3.1,
using CeTZ 0.5.3 and tikzDevice 0.12.6 with XeLaTeX.
Both devices receive the same deterministic R drawing
functions. The plots are compiled and rasterized at 144 PPI.


Results
-------

The recorded run used macOS arm64, R 4.5.2, TeX Live 2026, and Typst 0.15.1.

| Measure | Result |
|---|---:|
| R scenarios | 28 |
| Pages | 29 |
| Pages rendered by cetzDevice | 29 |
| Pages rendered by both devices | 28 |
| Comparable pages within geometry tolerance | 28 / 28 |
| Largest page-size difference | 0 pixels |
| Largest unmatched colored-pixel fraction | Approximately 2.59% (limit: 3%) |
| Reference-device failures | 1 page |

The four contact sheets and selected full-size figures were inspected.
Legends, bold and italic text, multiline and rotated labels, Unicode and
Chinese text, ggplot2 facets, and subscripts and superscripts showed no
new overflow or displacement. Small differences remain around projected
3D edges, arrowheads, and antialiasing. MiTeX's mathematics fonts and
placement of large-operator limits also differ from XeLaTeX.


Reference-Device Failure
------------------------

The extended plotmath scenario contains native R labels such as
`expression(alpha)`. In the recorded environment, tikzDevice 0.12.6
generated `\char-945` while measuring this label and XeLaTeX failed.
cetzDevice rendered the page. The CSV records this page as
`reference_limit`, with geometry values set to `NA`; it is excluded from
the 28 comparable pages.

The script recognizes this specific `\char-` error for that scenario.
Other reference errors, cetzDevice errors, missing pages, warnings, and
geometry failures cause the comparison to fail. The installed tikzDevice
was not modified.


Line Styles
-----------

For the dashed-line scenario with `lwd = 2`, tikzDevice writes a fixed
`on 4pt off 4pt` pattern in TeX points. cetzDevice writes `6pt/6pt` in
Typst points, following R's dash length multiplied by the line width:
`4 * 2 * 72/96 = 6`. The package separately compares scaled dash intervals
with R's native Cairo PNG output.


Scenarios
---------

The scenarios in `inst/validation/cases.R` adapt the test intent of
tikzDevice's [test_graphics.R][upstream], source blob
`140ee268c92de41902cf61cd2532dd157b07ab4a`. The file retains its source
and license notice.

- Base graphics: a minimal plot, frames, legends, point shapes 0–25,
  filled shapes, line styles, line widths, alpha, and a 500-point plot.
- Layout and text: contour panels, alignment, font faces and sizes,
  multiline and rotated text, LaTeX labels, and R plotmath.
- Geometry and images: compound fill rules, perspective projections,
  rotated rasters, and rasters with reversed extents.
- Annotations: base and grid helpers, including annotations before any
  visible primitive has been drawn.
- Packages and output: Unicode, Chinese text, ggplot2 facets and math
  labels, lattice rasters, and two-page output.

The comparison does not run the entire upstream test file. Legacy
ggplot2 branches, arbitrary LaTeX package and font commands, and
`symbolicColors` files are outside these scenarios. Gradient rendering is
covered separately by the Cairo comparisons in the package tests.


Configuration
-------------

Both devices use a 6 × 4 inch canvas and a random seed of 4. An adapter
selects the appropriate formula-label and annotation functions.

Ordinary scenarios use TeX Gyre Heros. Unicode uses Noto Sans; Chinese
text uses Noto Sans CJK SC. TeX has 72.27 points per inch and Typst has
72, so a reference size of 12 TeX points becomes `12 * 72 / 72.27` Typst
points. Line widths, annotation padding, and absolute coordinates are
converted to the same physical units.

tikzDevice's measurement code reads the global `tikzDocumentDeclaration`
option, so both that option and the device argument specify a 12pt
document. The measurement preamble retains `calc` and sets fonts through
`fontspec`. Adding `fontenc[T1]` afterward would change the measurement
font and introduce unrelated differences in legend widths and Chinese
text.

The output file `environment.json` records versions and settings.


Checks
------

Both renderers must produce the expected pages. Comparable page dimensions
may differ by at most one pixel. After a two-pixel dilation, the symmetric
unmatched fraction of the colored-pixel masks must not exceed 3%. Raw RGB
mean absolute error is recorded for diagnosis. R and compiler warnings,
including missing glyphs, are collected. The paired gallery is inspected
for text, legends, formulas, and clipping.

The colored masks reduce the effect of font antialiasing on the geometry
comparison. Separate package tests map source text pixels through whole-
plot transformations and check rotation, nonuniform scaling, shear,
reflection, cm/pt conversion, and named-anchor positions.


Reproducing the Comparison
-------------------------

Install the package, tikzDevice, ggplot2, lattice, the listed fonts,
XeLaTeX, Typst, and `pdftoppm`. From the repository root, run:

```sh
R CMD INSTALL .
Rscript dev/compare-tikz.R
```

Scenarios and output directories can be selected with environment variables:

```sh
CETZ_ACCEPTANCE_CASES=legend,cjk,ggplot_facets Rscript dev/compare-tikz.R
CETZ_ACCEPTANCE_OUTPUT=output/acceptance-other Rscript dev/compare-tikz.R
```

The default output directory is `output/acceptance/`:

- `index.html`: full-size paired gallery and reference error messages.
- `results.csv`: page status, geometry, warnings, errors, and reference failures.
- `summary.json` and `environment.json`: totals and environment information.
- `contact-1.png` through `contact-4.png`: contact sheets.
- `tikz/` and `cetz/`: source files, compiler logs, and page images.

To rebuild only the gallery and contact sheets:

```sh
Rscript dev/acceptance-gallery.R
```

Generated comparison files are kept under `output/` and excluded from Git.
Cross-platform package checks are run separately by GitHub Actions.

[upstream]: https://github.com/daqana/tikzDevice/blob/master/tests/testthat/test_graphics.R
