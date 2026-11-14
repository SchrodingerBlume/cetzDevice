args <- commandArgs(trailingOnly = TRUE)
metadata <- read.dcf("DESCRIPTION")[1L, ]
package <- unname(metadata[["Package"]])
version <- unname(metadata[["Version"]])
backend <- unname(metadata[["Config/cetzDevice/CeTZ"]])
typst <- unname(metadata[["Config/cetzDevice/Typst"]])
parts <- strsplit(version, ".", fixed = TRUE)[[1L]]
if (!grepl("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", version) ||
    paste(parts[1:3], collapse = ".") != backend || as.integer(parts[4L]) < 1L)
  stop("The package version must be the exact CeTZ version followed by a positive device revision")
tag <- paste0("v", version)
if (Sys.getenv("GITHUB_REF_TYPE") == "tag" && Sys.getenv("GITHUB_REF_NAME") != tag)
  stop("The release tag does not match DESCRIPTION: expected ", tag)

directory <- file.path("output", "releases", tag)
if (identical(args, "--metadata")) {
  values <- c(package = package, version = version, tag = tag, directory = directory)
  lines <- paste0(names(values), "=", values)
  output <- Sys.getenv("GITHUB_OUTPUT")
  if (nzchar(output)) cat(paste0(lines, "\n"), file = output, append = TRUE, sep = "")
  else writeLines(lines)
  quit(save = "no", status = 0L)
}
if (length(args) < 1L || length(args) > 2L)
  stop("Usage: Rscript dev/prepare-release.R CHECK_ARTIFACT [OUTPUT_DIRECTORY]")
input <- normalizePath(args[1L], mustWork = TRUE)
if (length(args) == 2L) directory <- args[2L]

archive_name <- paste0(package, "_", version, ".tar.gz")
archive <- file.path(input, archive_name)
check <- file.path(input, paste0(package, ".Rcheck"))
log <- readLines(file.path(check, "00check.log"), warn = FALSE)
status <- tail(grep("^Status:", log, value = TRUE), 1L)
if (!any(grepl("^\\* DONE", log)) ||
    length(status) != 1L || !grepl("^Status: (OK|[0-9]+ NOTEs?)$", status))
  stop("The source package must have a completed check without errors or warnings")

files <- utils::untar(archive, list = TRUE)
if (any(grepl("\\.(o|so|dll)$", files))) stop("Compiled objects found in the source archive")
sources <- paste0(package, "/", c("DESCRIPTION", "inst/doc/cetzDevice.pdf"))
if (!all(sources %in% files)) stop("Source metadata or built user manual is missing")
temp <- tempfile("cetz-release-")
dir.create(temp)
utils::untar(archive, files = sources, exdir = temp)
source_metadata <- read.dcf(file.path(temp, package, "DESCRIPTION"))[1L, ]
fields <- c("Package", "Version", "Config/cetzDevice/CeTZ", "Config/cetzDevice/Typst")
if (!identical(unname(source_metadata[fields]), unname(metadata[fields])))
  stop("The checked archive does not match the release metadata")

reference <- file.path(check, paste0(package, "-manual.pdf"))
if (!file.exists(reference)) stop("The checked API reference PDF is missing")
if (dir.exists(directory) && length(list.files(directory, all.files = TRUE, no.. = TRUE)))
  stop("The output directory is not empty: ", directory)
dir.create(directory, recursive = TRUE, showWarnings = FALSE)

copy <- function(from, name) {
  to <- file.path(directory, name)
  if (!file.copy(from, to)) stop("Cannot stage release asset: ", name)
  to
}
assets <- c(
  copy(archive, archive_name),
  copy(file.path(temp, package, "inst", "doc", "cetzDevice.pdf"),
       paste0(package, "-manual-", version, ".pdf")),
  copy(reference, paste0(package, "-reference-", version, ".pdf")))
unlink(temp, recursive = TRUE)

sha256 <- function(path) {
  command <- Sys.which("sha256sum")
  arguments <- shQuote(path)
  if (!nzchar(command)) {
    command <- Sys.which("shasum")
    arguments <- c("-a", "256", arguments)
  }
  if (!nzchar(command)) stop("Install sha256sum or shasum to prepare checksums")
  result <- system2(command, arguments, stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(result, "status"))) stop("Cannot calculate SHA-256: ", path)
  value <- strsplit(result[1L], "[[:space:]]+")[[1L]][1L]
  if (!grepl("^[a-f0-9]{64}$", value)) stop("Invalid SHA-256 result")
  value
}
commit <- Sys.getenv("GITHUB_SHA")
if (!nzchar(commit)) commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
run <- Sys.getenv("GITHUB_RUN_ID")
repository <- Sys.getenv("GITHUB_REPOSITORY", "SchrodingerBlume/cetzDevice")
build_info <- file.path(directory, "BUILD-INFO.txt")
writeLines(c(
  paste0("Package: ", package),
  paste0("Version: ", version),
  paste0("CeTZ: ", backend),
  paste0("Minimum Typst: ", typst),
  paste0("License: ", metadata[["License"]]),
  paste0("Commit: ", commit),
  paste0("Packaging R: ", R.version.string),
  sub("^\\* using R ", "Checked R: ", grep("^\\* using R ", log, value = TRUE)[1L]),
  sub("^\\* using platform: ", "Checked platform: ", grep("^\\* using platform: ", log, value = TRUE)[1L]),
  paste0("Source SHA-256: ", sha256(assets[1L])),
  if (nzchar(run)) paste0("Checks: https://github.com/", repository, "/actions/runs/", run)
), build_info)
assets <- c(assets, build_info)
writeLines(paste(vapply(assets, sha256, character(1L)), basename(assets), sep = "  "),
           file.path(directory, "SHA256SUMS"))

news <- readLines("NEWS.md", warn = FALSE)
start <- match(paste("#", package, version), news)
if (is.na(start)) stop("The release has no NEWS entry")
headings <- grep("^# |^## Development milestones", news)
end <- headings[headings > start]
end <- if (length(end)) min(end) - 1L else length(news)
changes <- news[seq.int(start + 1L, end)]
changes <- changes[changes != "Initial CRAN submission."]
while (length(changes) && !nzchar(trimws(changes[1L]))) changes <- changes[-1L]
while (length(changes) && !nzchar(trimws(tail(changes, 1L)))) changes <- head(changes, -1L)
writeLines(c(
  changes, "", "## Downloads", "",
  paste0("- `", archive_name, "`: checked R source package."),
  paste0("- `", basename(assets[2L]), "`: illustrated user manual."),
  paste0("- `", basename(assets[3L]), "`: API reference."),
  "- `SHA256SUMS`: SHA-256 checksums for all release assets.",
  "- `BUILD-INFO.txt`: package versions, source commit, and check provenance.",
  "", "## Installation", "", "```r",
  paste0('install.packages("', archive_name, '", repos = NULL, type = "source")'),
  "```", "",
  paste0("Requires R ", sub("^R \\(>= ([^)]+)\\)$", ">= \\1", metadata[["Depends"]]),
         " and a C compiler. Typst >= ", typst, " is used for text measurement and rendering."),
  paste0("Generated figures use CeTZ ", backend, ".")
), file.path(directory, "release-notes.md"))
message("Prepared ", tag, " in ", directory)
