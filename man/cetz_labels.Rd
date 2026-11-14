\name{cetz_typst}
\alias{cetz_typst}
\alias{cetz_latex}
\title{Mark Individual Labels as Typst or LaTeX Content}
\usage{
cetz_typst(x)
cetz_latex(x)
}
\arguments{\item{x}{A character vector of Typst markup or LaTeX text labels.}}
\description{
Mark plot labels as Typst markup or LaTeX text. These labels can be used with
base and grid graphics, including ggplot2. Ordinary strings remain plain text
when the device uses the default \code{text_mode = "plain"}.
}
\details{
Use dollar delimiters for mathematics in both modes. LaTeX is interpreted by
MiTeX 0.2.6; this is not a complete LaTeX engine and does not execute TikZ code.
Typst labels use eval in markup mode with the device's r-label-scope dictionary.
Both measurement and output use the same content. The labels require
metrics = "typst". The encoded character strings retain their interpretation
when plot objects are saved and restored in another R session.
}
\value{A character vector of encoded labels.}
\examples{
cetz_typst("$alpha^2$")
cetz_latex("$x^2$")
}
\seealso{\code{\link{cetz}}}
\keyword{device}
