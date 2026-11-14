Development
===========

Run the commands below from the repository root.


Repository Layout
-----------------

| Directory | Contents |
|---|---|
| `R/`, `src/` | R implementation and graphics-engine callbacks |
| `inst/typst/` | Typst runtime embedded in exported modules |
| `inst/validation/` | Deterministic rendering-comparison scenarios |
| `man/` | R help pages and API reference sources |
| `vignettes/` | User manual source, style, and rendered figures |
| `examples/` | Runnable plotting examples |
| `dev/` | Documentation, comparison, cleanup, and release tools |
| `docs/` | Published manual and rendering-comparison reports |
| `tests/` | Package tests |
| `output/` | Generated files, check logs, archives, and submission records; ignored by Git |


Checks and Examples
-------------------

```sh
R CMD INSTALL .
Rscript examples/demo.R
Rscript -e 'testthat::test_local()'
```

The `R and Typst checks` workflow runs `R CMD check --as-cran` on Windows,
macOS, and Ubuntu with the minimum and latest Typst versions. Additional
jobs cover R-devel, R-oldrel, and export without Typst.


Manual and Rendering Comparison
-------------------------------

```sh
Rscript dev/build-manual.R
Rscript dev/compare-tikz.R
```

The manual build requires knitr, LaTeX, latexmk, Typst, and ggplot2.
It updates `docs/cetzDevice.pdf` and the figure PDFs under `vignettes/figures/`.
The rendering comparison also requires tikzDevice, XeLaTeX, `pdftoppm`,
and the fonts described in `docs/acceptance.md`.


Generated Files
---------------

Archive old source tarballs, root-level check output, compiled objects,
and temporary manual files with:

```sh
Rscript dev/clean.R --dry-run
Rscript dev/clean.R
```

Files are moved to `output/archive/`. Tracked sources and existing files
under `output/`, including CRAN submission records, are retained.


Releases
--------

The `Package and release` workflow runs when a version tag is pushed:

```sh
git tag v0.5.3.1
git push origin v0.5.3.1
```

It can also be started from GitHub Actions or the CLI:

```sh
gh workflow run release.yaml --repo SchrodingerBlume/cetzDevice --ref main
```

The workflow reads the version from `DESCRIPTION`. A pushed tag must match
that version. The package's first three version components must match
`Config/cetzDevice/CeTZ`; the fourth is a positive device revision.

All nine package checks must pass before publication. The release job uses
the source tarball checked by the Ubuntu R-release / Typst 0.15.0 job.
It extracts the user manual from that archive and includes the checked API
reference, SHA-256 checksums, and build information. The source package is
not rebuilt between its check and publication.

To prepare the same assets locally from a downloaded check artifact:

```sh
Rscript dev/prepare-release.R path/to/check-artifact output/releases/local
```

Published releases are not overwritten. Use a new device revision for a
changed release. GitHub publication does not upload anything to CRAN;
CRAN submission and maintainer email confirmation remain separate.
