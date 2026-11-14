metadata <- read.dcf("DESCRIPTION")[1L, ]
package <- unname(metadata[["Package"]])
paths <- c(
  list.files(pattern = paste0("^", package, "_[0-9.]+\\.tar\\.gz$")),
  if (file.exists(file.path(paste0(package, ".Rcheck"), "00check.log")))
    paste0(package, ".Rcheck"),
  list.files("src", pattern = "\\.(o|so|dll)$", full.names = TRUE),
  list.files("vignettes", pattern = paste0("^", package, "\\.(tex|aux|log|out|toc|pdf|R)$"),
             full.names = TRUE),
  list.files(file.path("vignettes", "figures"), pattern = "\\.(typ|svg|rds)$",
             full.names = TRUE))
paths <- paths[vapply(paths, function(path) {
  system2("git", c("check-ignore", "--quiet", "--", shQuote(path))) == 0L
}, logical(1L))]
if (!length(paths)) {
  message("No generated build files to archive")
} else {
  archive <- file.path("output", "archive", paste0(
    "builds-", format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC"), "-", Sys.getpid()))
  dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)
  for (path in paths) {
    target <- file.path(archive, path)
    message(if (dry_run) "Would archive " else "Archiving ", path, " -> ", target)
    if (!dry_run) {
      dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
      if (!file.rename(path, target)) stop("Cannot archive ", path)
    }
  }
}
