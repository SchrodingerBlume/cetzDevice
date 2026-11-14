\name{cetz_cache_info}
\alias{cetz_cache_info}
\alias{cetz_clear_cache}
\title{Inspect or Clear the Text Measurement Cache}
\usage{
cetz_cache_info()
cetz_clear_cache(cache_dir = NULL)
}
\arguments{\item{cache_dir}{Optional persistent cache directory to clear.
Only cetzDevice metric files matching its generated filename pattern are removed.}}
\description{
Text measurements are shared between devices in the R session and optionally
stored in a persistent directory. Inspect entry, hit, miss and measurement
subprocess counts, or clear the memory cache and optionally persistent entries.
}
\details{
The typst_calls counter counts measurement queries, not CLI version probes.
Cache keys account for font styles, backend version, content, preambles and
statically named local imports/data dependencies. Installed font changes and
dynamic dependencies require clearing the cache or changing cetz's cache_key.
}
\value{
\code{cetz_cache_info()} returns a list with \code{entries}, \code{hits},
\code{misses}, and \code{typst_calls}. \code{cetz_clear_cache()} returns
\code{NULL} invisibly.
}
\examples{cetz_cache_info()}
\seealso{\code{\link{cetz}}}
