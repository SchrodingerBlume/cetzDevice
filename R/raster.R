# Share embedded PNG data across drawing operations and pages.
.record_raster <- function(data, state) {
  pixels <- data[[1L]]
  at <- data[[2L]]
  if (any(!is.finite(at))) stop("Non-finite raster geometry", call. = FALSE)
  if (at[3L] < 0 || at[4L] < 0) {
    # Native rasters use row-major storage.
    order <- matrix(seq_along(pixels), nrow = nrow(pixels), byrow = TRUE)
    if (at[3L] < 0) order <- order[, rev(seq_len(ncol(order))), drop = FALSE]
    if (at[4L] < 0) order <- order[rev(seq_len(nrow(order))), , drop = FALSE]
    pixels[] <- as.vector(pixels)[as.vector(t(order))]
  }
  encoded <- png::writePNG(pixels)
  for (i in seq_along(state$images)) {
    if (identical(encoded, state$images[[i]])) return(list(i, at))
  }
  id <- length(state$images) + 1L
  state$images[[id]] <- encoded
  list(id, at)
}

.raster_operation <- function(data) {
  at <- data[[2L]]
  angle <- at[5L] * pi / 180
  # Keep R's rotation origin when the image extent is reflected.
  x <- at[1L] + at[3L] / 2 * cos(angle) - at[4L] / 2 * sin(angle)
  y <- at[2L] + at[3L] / 2 * sin(angle) + at[4L] / 2 * cos(angle)
  paste0("content(", .point(x, y), ", anchor: \"center\", angle: ",
         .num(at[5L]), "deg, box(image(r-images.at(", data[[1L]] - 1L,
         "), width: ", .num(abs(at[3L])), "pt, height: ",
         .num(abs(at[4L])), "pt, fit: \"stretch\", scaling: ",
         .str(if (at[6L] != 0) "smooth" else "pixelated"), ")))")
}

.image_definitions <- function(images) {
  if (!length(images)) return(character())
  c("#let r-images = (", unlist(lapply(images, function(image) {
    values <- as.integer(image)
    chunks <- split(values, (seq_along(values) - 1L) %/% 24L)
    c("  bytes((", vapply(chunks, function(chunk) {
      paste0("    ", paste(chunk, collapse = ", "), ",")
    }, character(1L), USE.NAMES = FALSE), "  )),")
  }), use.names = FALSE), ")", "")
}
