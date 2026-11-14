cetzDevice
==========

[![R build status](https://github.com/SchrodingerBlume/cetzDevice/actions/workflows/check.yaml/badge.svg)](https://github.com/SchrodingerBlume/cetzDevice/actions/workflows/check.yaml)
[![GitHub release](https://img.shields.io/github/v/release/SchrodingerBlume/cetzDevice)](https://github.com/SchrodingerBlume/cetzDevice/releases/latest)
[![R version](https://img.shields.io/badge/R-%3E%3D%204.1.0-blue.svg)](https://www.r-project.org/)
[![CeTZ version](https://img.shields.io/badge/CeTZ-0.5.3-blue.svg)](https://typst.app/universe/package/cetz/0.5.3/)
[![Typst version](https://img.shields.io/badge/Typst-%3E%3D%200.15.0-blue.svg)](https://github.com/typst/typst)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue.svg)](https://www.r-project.org/Licenses/GPL-3)

The cetzDevice package provides a graphics output device for R that records
plots in a Typst-friendly format. The device transforms plotting commands
issued by R functions into Typst code blocks. When included in a paper typeset
by Typst, these blocks are interpreted with the help of [CeTZ][cetz], a drawing
package written by Johannes Wolf, fenjalien, and contributors.

Using cetzDevice, the text of R plots can contain Typst markup and mathematical
formulae. LaTeX labels can also be used through [MiTeX][mitex]. The device allows
arbitrary CeTZ code to be inserted into the output stream.

The cetzDevice supports three main modes of output:

  - Figure chunks: placed in `.typ` files and suitable for inclusion in Typst
    documents via `#import` and `r-figure()`.

  - Stand alone figures: complete Typst documents containing figure code that
    can be compiled into stand-alone images. Pages are cropped to the size of
    the figure.

  - Console output: CeTZ code is written directly to the R console for further
    manipulation.

Base graphics and grid graphics, including ggplot2, are supported. Figures can
also be placed inside an existing CeTZ canvas using `r-draw()` or `r-elements()`.

See the [package manual][manual] for usage and examples. When installed with
vignettes, the same manual is available from R:

```r
vignette("cetzDevice", package = "cetzDevice")
```


Obtaining the Package
---------------------

Source packages, the user manual, and the API reference are available from
[GitHub Releases][releases]. To install a downloaded source package:

```r
install.packages("cetzDevice_0.5.3.1.tar.gz", repos = NULL, type = "source")
```

Development builds may be installed directly from GitHub:

```r
install.packages("remotes")
remotes::install_github("SchrodingerBlume/cetzDevice")
```

Add `build_vignettes = TRUE` to install the manual as a vignette. Building
the manual requires LaTeX.

Source code is available from GitHub, too:

```sh
git clone https://github.com/SchrodingerBlume/cetzDevice.git
R CMD INSTALL cetzDevice
```

Building from source requires R 4.1.0 or newer and a C compiler. The default
text measurement backend requires the [Typst CLI][typst], version 0.15.0 or
newer. Exported figures use CeTZ 0.5.3; Typst downloads this package on first use.
An installed copy in Typst's package cache can be used offline.

The optional `systemfonts` backend allows plots with plain text labels to be
exported without running Typst. Typst is still needed to compile the figures.


Version Numbers
---------------

The package version has four components. The first three give the exact
CeTZ version; the fourth counts cetzDevice releases for that version,
starting at one. For example, `0.5.3.2` is the second device release for
CeTZ `0.5.3`. The device revision restarts at one when the CeTZ version changes.

Support starts with CeTZ **0.5.3**; earlier CeTZ releases have not been adapted.
This release requires Typst **0.15.0** or newer. `cetz_backend()` reports the
pinned CeTZ version and the minimum Typst version.


Reporting Bugs and Getting Help
-------------------------------

Primary development takes place on GitHub. The preferred way to communicate
bugs and feature requests is to open an issue at the primary repository:

  https://github.com/SchrodingerBlume/cetzDevice/issues

Please include the R code needed to reproduce the problem, the output of
`sessionInfo()`, and the Typst version. Questions about usage may be posted
there as well.

Users are encouraged to fork the repository and contribute to the development
of the package. See the [development guide][development] for checks,
documentation builds, and automated releases.


Acknowledgements
----------------

The design of this package follows [tikzDevice][tikzdevice], originally written
by Charlie Sharpsteen and Cameron Bracken and maintained by Ralf Stubner and
contributors. Its approach to graphics output and typesetter-based font
metrics provided the model for cetzDevice. The organization of this README and
the package manual follows their documentation.

We would also like to thank Johannes Wolf, fenjalien, and the [CeTZ][cetz]
contributors for the drawing library used by every figure produced by this
device, and the R Core Team for the R graphics engine.


Latest Changes
--------------

*See the [NEWS][news] file for latest changes.*

[cetz]: https://github.com/cetz-package/cetz
[mitex]: https://github.com/mitex-rs/mitex
[typst]: https://github.com/typst/typst
[tikzdevice]: https://github.com/daqana/tikzDevice
[manual]: https://github.com/SchrodingerBlume/cetzDevice/blob/main/docs/cetzDevice.pdf
[releases]: https://github.com/SchrodingerBlume/cetzDevice/releases
[development]: https://github.com/SchrodingerBlume/cetzDevice/blob/main/dev/README.md
[news]: NEWS.md
