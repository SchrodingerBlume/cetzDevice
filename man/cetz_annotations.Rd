\name{cetz_annotate}
\alias{cetz_annotate}
\alias{cetz_coord}
\alias{cetz_node}
\alias{cetz_annotate_grob}
\alias{cetz_coord_grob}
\alias{cetz_node_grob}
\title{Add Native CeTZ Annotations to R Plots}
\usage{
cetz_annotate(code, clip = FALSE)
cetz_coord(x, y, name, units = "user")
cetz_node(x, y, content, name = NULL,
          units = "user", angle = 0, anchor = "center",
          options = NULL, clip = FALSE)
cetz_annotate_grob(code, clip = FALSE)
cetz_coord_grob(x, y, name, units = "native")
cetz_node_grob(x, y, content, name = NULL,
               units = "native", angle = 0, anchor = "center",
               options = NULL, clip = FALSE, gp = grid::gpar())
}
\arguments{
  \item{code}{CeTZ source lines in code mode, without leading hash prefixes.}
  \item{clip}{Use the current R clipping region instead of the full device.}
  \item{x,y}{Numeric base graphics coordinates, or numeric/unit grid positions.}
  \item{name}{A named coordinate or optional node name. Coordinate names must
  be unique within the page and cannot contain dots.}
  \item{units}{Base coordinate system as in grconvertX, or grid unit system.}
  \item{content}{A scalar text, numeric or logical label, optionally marked with
  cetz_typst or cetz_latex.}
  \item{angle}{Counterclockwise rotation in degrees.}
  \item{anchor}{CeTZ content anchor.}
  \item{options}{Additional CeTZ style arguments supplied as source code.}
  \item{gp}{Grid graphical parameters for node text.}
}
\description{
Insert native CeTZ code, coordinates or content nodes into the active device.
Base functions use the current graphics coordinate system. Grid constructors
return grobs that are positioned when drawn with grid.draw(). Grid positions
must be scalar units. Grid node text respects viewport rotation, alpha and
the first value of each graphical parameter for its single label.
}
\details{
Start a plot before adding annotations. Coordinates registered with cetz_coord
or cetz_coord_grob are available in every clipping layer. Named nodes and raw
CeTZ shapes are also retained across later clipping layers. r-draw exports
their full anchor functions on its group; clipped r-elements exposes them
in the containing canvas. Source code uses the device's preamble definitions.
For example, options may contain:
\preformatted{frame: "rect", padding: 2}
}
\examples{
if (requireNamespace("systemfonts", quietly = TRUE)) {
  file <- tempfile(fileext = ".typ")
  cetz(file, width = 5, height = 4, metrics = "systemfonts")
  plot(1:5, (1:5)^2)
  cetz_coord(4, 16, "marked")
  cetz_node(2, 20, "A label", name = "label")
  cetz_annotate('line("label.east", "marked", stroke: red)')
  dev.off()
}
}
\value{
The grob constructors return grid grobs. cetz_coord invisibly returns its
position in device points. Other base helpers return NULL invisibly.
}
\seealso{\code{\link{cetz}}, \code{\link{cetz_typst}}}
\keyword{device}
