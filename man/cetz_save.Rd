\name{cetz_save}
\alias{cetz_save}
\title{Save a Plot as CeTZ Source}
\usage{
cetz_save(file, plot, ...)
}
\arguments{
  \item{file}{Output Typst source file.}
  \item{plot}{A plot object to print, such as a ggplot object, or a zero-argument
  function that performs base or grid drawing.}
  \item{...}{Arguments passed to \code{\link{cetz}}.}
}
\description{
Save a plot object or a drawing function's output as CeTZ source. The function
opens a device with \code{cetz()}, draws the plot, and closes the device.
}
\details{
A function supplied as \code{plot} is called without arguments. Other objects
are drawn with \code{print()}. The device is also closed if drawing fails,
and the drawing error is reported to the caller. Errors writing the output
file are reported after device cleanup.
}
\value{Invisibly, the output path.}
\examples{
if (requireNamespace("systemfonts", quietly = TRUE)) {
  cetz_save(tempfile(fileext = ".typ"), function() plot(pressure),
            width = 5, height = 4, metrics = "systemfonts")
}
}
\seealso{\code{\link{cetz}}}
\keyword{device}
