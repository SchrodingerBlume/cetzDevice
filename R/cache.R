.metrics_cache <- new.env(parent = emptyenv())
.typst_versions <- new.env(parent = emptyenv())
.cache_stats <- new.env(parent = emptyenv())
.cache_stats$hits <- .cache_stats$misses <- .cache_stats$typst_calls <- 0L

#' Inspect the session text metric cache
#' @return A list of entry, hit, miss and Typst subprocess counts.
#' @export
cetz_cache_info <- function() {
  c(list(entries = length(.metrics_cache)), as.list(.cache_stats))
}

#' Clear cached text measurements
#' @param cache_dir Optional persistent cache directory. Only cetzDevice metric
#'   files in that directory are removed.
#' @return Invisibly, NULL.
#' @export
cetz_clear_cache <- function(cache_dir = NULL) {
  rm(list = ls(.metrics_cache, all.names = TRUE), envir = .metrics_cache)
  rm(list = ls(.typst_versions, all.names = TRUE), envir = .typst_versions)
  .cache_stats$hits <- .cache_stats$misses <- .cache_stats$typst_calls <- 0L
  if (!is.null(cache_dir)) {
    if (!is.character(cache_dir) || length(cache_dir) != 1L || is.na(cache_dir))
      stop("'cache_dir' must be a directory path", call. = FALSE)
    files <- list.files(path.expand(cache_dir),
      pattern = "^cetz-metric-[a-f0-9]{64}\\.rds$", full.names = TRUE)
    unlink(files)
  }
  invisible(NULL)
}

.typst_version <- function(executable) {
  info <- file.info(executable)
  key <- digest::digest(list(executable, info$size, info$mtime), algo = "sha256")
  if (!exists(key, .typst_versions, inherits = FALSE)) {
    version <- suppressWarnings(system2(executable, "--version", stdout = TRUE, stderr = TRUE))
    if (!is.null(attr(version, "status"))) stop("Cannot run Typst CLI", call. = FALSE)
    .typst_versions[[key]] <- version
  }
  .typst_versions[[key]]
}

# Hash local dependencies recursively; dynamic paths use cache_key.
.preamble_dependencies <- function(lines, root) {
  visited <- new.env(parent = emptyenv())
  visit <- function(source, directory) {
    matches <- regmatches(paste(source, collapse = "\n"), gregexpr(
      '(?:import|include|read|json|csv|yaml|toml)\\s*(?:\\(\\s*)?"[^"]+"',
      paste(source, collapse = "\n"), perl = TRUE))[[1L]]
    for (match in matches) {
      path <- sub('^[^"]*"([^"]+)"$', '\\1', match)
      if (startsWith(path, "@")) next
      path <- if (startsWith(path, "/")) file.path(root, substring(path, 2L)) else file.path(directory, path)
      path <- normalizePath(path, mustWork = FALSE)
      if (exists(path, visited, inherits = FALSE)) next
      visited[[path]] <- if (file.exists(path) && !dir.exists(path))
        digest::digest(file = path, algo = "sha256") else "missing"
      if (file.exists(path) && grepl("\\.typ$", path)) visit(readLines(path, warn = FALSE), dirname(path))
    }
  }
  visit(lines, root)
  values <- as.list(visited, all.names = TRUE)
  if (length(values)) values[order(names(values))] else list()
}

.cache_get <- function(key, directory) {
  value <- .metrics_cache[[key]]
  # Persist session hits when disk caching is requested later.
  if (!is.null(value) && !is.null(directory)) .cache_put(key, value, directory)
  if (is.null(value) && !is.null(directory)) {
    file <- file.path(directory, paste0("cetz-metric-", key, ".rds"))
    if (file.exists(file)) value <- tryCatch(readRDS(file), error = function(e) NULL)
    if (!is.numeric(value) || length(value) != 3L || any(!is.finite(value))) {
      value <- NULL
      if (file.exists(file)) unlink(file)
    }
    if (!is.null(value)) .metrics_cache[[key]] <- value
  }
  if (!is.null(value)) .cache_stats$hits <- .cache_stats$hits + 1L
  value
}

.cache_put <- function(key, value, directory) {
  .metrics_cache[[key]] <- value
  if (!is.null(directory)) {
    target <- file.path(directory, paste0("cetz-metric-", key, ".rds"))
    if (!file.exists(target)) {
      temp <- tempfile(".cetz-cache-", tmpdir = directory)
      on.exit(unlink(temp), add = TRUE)
      tryCatch({
        saveRDS(value, temp)
        if (!file.rename(temp, target) && !file.exists(target))
          warning("Could not save text metric cache entry", call. = FALSE)
      }, error = function(e) warning("Could not save text metric cache: ", conditionMessage(e), call. = FALSE))
    }
  }
  invisible(value)
}
