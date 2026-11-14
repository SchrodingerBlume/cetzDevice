\name{cetzDevice-package}
\alias{cetzDevice-package}
\alias{cetzDevice}
\docType{package}
\title{CeTZ Graphics Output in Typst Format}
\description{
Provides an R graphics output device that records plotting commands as CeTZ
source for inclusion in Typst documents. Typst typesets the labels and
annotations, including native mathematics and LaTeX text through MiTeX.
}
\details{
Open the device with \code{\link{cetz}}, draw with the usual base or grid
graphics functions, and close it with \code{\link[grDevices]{dev.off}}.
The output is written when the device closes. The function
\code{\link{cetz_save}} opens, draws, and closes a device in one call.

The device has three output modes:
\describe{
  \item{Figure chunks}{Typst modules imported into a document with
  \code{\#import} and drawn with \code{r-figure()}.}
  \item{Stand alone figures}{Complete Typst documents suitable for direct
  compilation, selected with \code{standalone = TRUE}.}
  \item{Console output}{Module source written to standard output, selected
  with \code{console = TRUE} or an empty filename.}
}
The module also exports \code{r-draw()} and \code{r-elements()} for use
inside a CeTZ canvas.

The package manual is available with
\code{vignette("cetzDevice", package = "cetzDevice")}. It contains usage
and examples, an installation guide, and a description of the device internals.
}
\section{Font Size Calculations}{
Device dimensions are in inches. Text sizes and drawing coordinates use
Typst points, with 72 points per inch. The device measures labels using
the selected family, face, size, and text interpretation. The default backend
calls Typst; the optional systemfonts backend provides approximate plain text
measurements.

R calculates plot layout during export. Choose the final figure size and
font before plotting. Measurements are cached across devices and can also
be saved on disk; see \code{\link{cetz_cache_info}}.
}
\section{Version Numbers}{
The first three package version components identify the exact CeTZ version.
The fourth counts device releases for that version, starting at one.
For example, 0.5.3.2 is the second device release for CeTZ 0.5.3. The
revision restarts at one when the CeTZ version changes.

Support starts with CeTZ 0.5.3; earlier CeTZ releases have not been adapted.
This release requires Typst 0.15.0 or newer. See \code{\link{cetz_backend}}
for the exact versions.
}
\section{Acknowledgements}{
The device design and the organization of the documentation follow
\pkg{tikzDevice}, originally written by Charlie Sharpsteen and Cameron
Bracken and maintained by Ralf Stubner and contributors.
\url{https://github.com/daqana/tikzDevice}

The generated drawings use CeTZ, written by Johannes Wolf, fenjalien,
and contributors. \url{https://github.com/cetz-package/cetz}

We also thank the R Core Team, Paul Murrell, and the Typst and MiTeX
developers for the graphics engine, typesetting, and label support.
}
\references{
The cetzDevice manual: \code{vignette("cetzDevice")}.

CeTZ documentation: \url{https://cetz-package.github.io/}.

Typst documentation: \url{https://typst.app/docs/}.
}
\author{Andrew Junhao Wu}
\seealso{
\code{\link{cetz}}, \code{\link{cetz_save}},
\code{\link{cetz_typst}}, \code{\link{cetz_annotate}},
\code{\link{cetz_cache_info}}, \code{\link{cetz_backend}}
}
\keyword{package}
\keyword{device}
