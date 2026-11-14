## Resubmission

This is a resubmission of cetzDevice, version 0.5.3.1, following Uwe Ligges's
review. Both requested changes have been made:

- Software names are single-quoted in both the Title and Description fields
  of DESCRIPTION, including 'CeTZ', 'Typst', and 'MiTeX'.
- The README manual link now uses the public HTTPS URL
  https://github.com/SchrodingerBlume/cetzDevice/blob/main/docs/cetzDevice.pdf
  instead of the relative path docs/cetzDevice.pdf.

## Test environments

- Windows and macOS arm64: R-release, with Typst 0.15.0 and latest.
- Ubuntu: R-release, with Typst 0.15.0 and latest.
- Ubuntu: R-oldrel and R-devel, with Typst latest.
- Ubuntu: R-release without Typst.

## Check results

All nine CI jobs pass R CMD check --as-cran with no ERRORs or WARNINGs,
including reference-manual generation and vignette rebuilding.

The exact submission tarball was also checked with R 4.6.2 on macOS arm64
after the GitHub repository became public. There were no ERRORs or WARNINGs,
and both the repository and BugReports URLs passed the incoming URL check.

The incoming check reports "New submission". HTML validation is skipped on
the local machine and Linux runners because HTML Tidy is outdated or absent.
The Windows check completes HTML validation successfully.

## External software

Typst >= 0.15.0 is used for text measurements and rendering. Typst-dependent
examples and tests are skipped when the executable is absent. Plain-text
export through systemfonts remains available. Vignette figures are supplied
with their source examples, so vignette rebuilding does not require Typst.

Typst measurement and rendering tests use at most two compilation jobs.
