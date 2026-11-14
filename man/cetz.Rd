\name{cetz}
\alias{cetz}
\title{CeTZ Graphics Device}
\usage{
cetz(file = "Rplots.typ", width = 7, height = 7,
     pointsize = 12, family = "Arial", bg = "white",
     standalone = FALSE,
     metrics = c("typst", "systemfonts"),
     typst = Sys.which("typst"),
     font_map = c(
       sans = "Arial", serif = "Times New Roman",
       mono = "Courier New", symbol = "Symbol"),
     text_mode = c("plain", "typst", "latex"),
     preamble = character(), cache_dir = NULL,
     cache_key = "default", fg = "black", lwd_unit = 0.75,
     onefile = TRUE, console = FALSE)
}
\arguments{
  \item{file}{Output Typst source file. Written when the device closes.}
  \item{width, height}{Positive device dimensions in inches.}
  \item{pointsize}{Initial font size in points.}
  \item{family}{Default font family available to the measurement backend and Typst.}
  \item{bg}{Background colour, including alpha or \code{"transparent"}.}
  \item{standalone}{Include page setup and render all pages for direct compilation.}
  \item{metrics}{Use cached Typst measurements, or faster approximate systemfonts measurements.}
  \item{typst}{Path to the Typst CLI, required for Typst measurements.}
  \item{font_map}{Named character vector mapping R family names to font families.}
  \item{text_mode}{Interpret unmarked strings as literal text, Typst markup or
  LaTeX text through MiTeX. Native markup requires Typst measurements.}
  \item{preamble}{Typst source lines shared by measurement and output. Relative
  imports resolve beside the output file. Define \code{r-label-scope} to expose
  names to Typst label evaluation.}
  \item{cache_dir}{Optional persistent measurement cache directory. Session
  measurements are shared across devices even when this is NULL.}
  \item{cache_key}{Additional invalidation key for changed fonts or dynamic dependencies.}
  \item{fg}{Starting foreground colour.}
  \item{lwd_unit}{Physical line width in Typst points for R lwd = 1.}
  \item{onefile}{Write all pages to one module. If FALSE, file must contain one
  integer placeholder such as \code{figure-\%03d.typ}.}
  \item{console}{Print the module to standard output. An empty file path also
  selects console mode. Requires onefile = TRUE.}
}
\description{
\code{cetz()} opens an R graphics device which supports output in the CeTZ
drawing language. The resulting Typst module can be imported into a document
or drawn inside a CeTZ canvas. Close the device with \code{dev.off()} to write
the output.
}
\details{
The device records graphics commands as CeTZ source. Typst typesets the
text in the plot, so labels can use the same fonts as the surrounding
document. Use \code{\link{cetz_typst}} or \code{\link{cetz_latex}} for
mathematical labels; ordinary strings are treated as plain text.

By default, the output is a module intended for inclusion in another Typst
document. It exports \code{r-figure(page: 1)} and the \code{r-figures} array.
For example:
\preformatted{
  #import "Rplots.typ": r-figure
  #figure(r-figure(), caption: [An R plot.])
}
When \code{standalone = TRUE}, the module includes page settings and draws
all its pages. The file can then be compiled directly with
\code{typst compile Rplots.typ}. It remains usable as an imported module.

When \code{console = TRUE}, the module is written to standard output.
An empty filename selects the same mode. Console output requires
\code{onefile = TRUE}.

The output imports CeTZ 0.5.3 and requires Typst 0.15.0 or newer.
See \code{\link{cetz_backend}} for the target versions and
\code{vignette("cetzDevice")} for the package manual.
}
\section{Embedding in a CeTZ Canvas}{
The module exports \code{r-draw()} to place a complete clipped plot in an
existing CeTZ canvas. The plot retains its physical size and exposes its
named coordinates and node anchors on the resulting group.

The function \code{r-elements()} returns raw elements in point coordinates,
for use in a canvas with \code{length: 1pt}. It omits R's clipping containers
by default. Passing \code{clip: true} uses layered content containers to
retain clipping of text, paths, images, and full stroke extents.
Clipped embedding and \code{r-draw()} apply two-dimensional affine
transformations to the whole scene and its named anchors. Unclipped
elements follow CeTZ's native rules for text and physical stroke widths.
}
\section{Font Size Calculations}{
There are 72 Typst points to the inch. Text is measured and drawn using
the font family, face, and size supplied by R's graphics engine. Plot
layout is calculated at the export size. Choose the final dimensions
and font settings before drawing the plot.

The systemfonts backend records the resolved system family in the output,
including substitutions for unavailable requested fonts. The compiling
machine needs the same fonts.
}
\section{Images and Gradients}{
Raster images are embedded as PNG bytes in the generated source, with no
external image files. Rotation, reflected extents, alpha and interpolation
hints are preserved. Identical images share one resource across pages.
Linear and nested-circle radial gradients are embedded as SVG vector fills,
preserving device-space geometry, stops, alpha and extension modes. Radial
circles must have different radii, with the inner circle contained in the outer
one. Tiling patterns, masks, arbitrary clipping paths, glyph runs and advanced
compositing are not implemented.
}
\section{Text and Caching}{
Output is written as UTF-8. R plotmath expressions are laid out by R's
graphics engine. Use \code{\link{cetz_typst}} for native Typst mathematics
or \code{\link{cetz_latex}} for MiTeX 0.2.6's supported LaTeX commands.

Cache keys include backend version, content, style, preamble and statically
named local dependencies. Clear the cache or change cache_key after changing
installed fonts or dynamic dependencies.
}
\value{Invisibly, the device number.}
\examples{
if (requireNamespace("systemfonts", quietly = TRUE)) {
  file <- tempfile(fileext = ".typ")
  cetz(file, width = 5, height = 4, metrics = "systemfonts")
  plot(pressure)
  dev.off()
}
}
\references{
CeTZ: \url{https://github.com/cetz-package/cetz}.

tikzDevice: \url{https://github.com/daqana/tikzDevice}.
}
\seealso{\code{\link{cetzDevice-package}}, \code{\link{cetz_save}},
\code{\link{cetz_typst}}, \code{\link{cetz_annotate}}}
\author{Andrew Junhao Wu}
\keyword{device}
