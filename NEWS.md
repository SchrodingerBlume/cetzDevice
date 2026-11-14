# cetzDevice 0.5.3.1

Initial CRAN submission.

- Record base and grid graphics, including ggplot2 plots, as editable CeTZ
  source for Typst documents.
- Support figure modules, stand-alone documents, console output, multiple
  pages, and embedding in an existing CeTZ canvas.
- Measure text with Typst or systemfonts; cache measurements across devices
  and optionally across R sessions.
- Support Typst and MiTeX labels, native CeTZ annotations, named coordinates,
  rectangular clipping, embedded rasters, and vector gradient fills.
- Include a package manual, API reference, rendering comparisons, and
  cross-platform checks.
- Use the exact CeTZ version as the first three version components, followed
  by a device revision starting at one. This release pins CeTZ 0.5.3 and
  requires Typst >= 0.15.0.
- Quoted software names in the DESCRIPTION Title and Description fields.
- Replaced the README's relative manual link with its public GitHub URL.

## Development milestones

The following milestones summarize development before the first formal
release. They were not CRAN releases.

### 0.0.4

- Added linear and nested-circle radial gradients, vector color bars, and
  clipped embedding with complete affine transformations and named anchors.
- Aligned measured and rendered fallback fonts and corrected grid node
  rotation, transparency, and scalar graphical parameters.
- Added device-error recovery for R 4.6 and checks on Windows, macOS, and Linux.
- Added the tikzDevice rendering comparison and the package manual.

### 0.0.3

- Added native Typst and MiTeX labels, shared preambles, and persistent
  measurement caching.
- Added CeTZ annotations, named coordinates, grid grobs, and canvas embedding.
- Added per-page files, console output, and shared stroke definitions.

### 0.0.2

- Added embedded PNG rasters for base graphics, grid, and ggplot2.
- Preserved image transparency, rotation, reflection, interpolation hints,
  clipping, and drawing order.

### 0.0.1

- Implemented the R graphics engine device with CeTZ vector output, Typst
  text measurement, rectangular clipping, and multiple pages.
