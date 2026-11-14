\name{cetz_backend}
\alias{cetz_backend}
\title{Inspect the Target CeTZ and Typst Versions}
\usage{cetz_backend()}
\description{
Return the exact CeTZ version used by generated modules and its minimum
Typst compiler version. The first three package version components identify
the exact CeTZ version; the fourth counts device releases for that version.
}
\details{
The device revision starts at one for each CeTZ version. For example,
0.5.3.2 is the second device release for CeTZ 0.5.3. The revision restarts
at one when the CeTZ version changes.

Support starts with CeTZ 0.5.3; earlier CeTZ releases have not been adapted.
}
\value{A list with character entries \code{cetz} and \code{typst_min}.}
\examples{cetz_backend()}
