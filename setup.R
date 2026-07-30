#!/usr/bin/env Rscript
# ============================================================================
# setup.R  —  lightweight environment bootstrap (fallback for non-renv users)
#
# `renv.lock` is the authoritative, exact-version environment for this repo:
#     renv::restore()
# This script is the simpler alternative — it installs the packages the audit
# and figures need, with retries for flaky mirrors, and reports installed
# versions against the known-good set below.
#
# Known-good versions (from the sessionInfo() captured when the audit was run):
#     R          4.3.x
#     Eunomia    2.0.0     DBI       1.3.0     RSQLite   3.53.3
#     ggplot2    (figures) any recent 3.5.x is fine
# ============================================================================

required <- c(
  "Eunomia", "DBI", "RSQLite",   # audit: fetch + query GiBleed
  "ggplot2"                      # scripts/make-figures.R
)

options(repos = c(CRAN = "https://cloud.r-project.org"),
        download.file.method = "libcurl", timeout = 300)

missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  for (i in 1:5) {
    install.packages(missing, dependencies = TRUE)
    missing <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
    if (!length(missing)) break
    message("retry ", i, " - still missing: ", paste(missing, collapse = ", "))
    Sys.sleep(3)
  }
}
stopifnot("packages failed to install" = !length(missing))

cat("\nInstalled versions:\n")
for (pkg in required)
  cat(sprintf("  %-10s %s\n", pkg, as.character(packageVersion(pkg))))
cat("\nEnvironment ready. Reproduce the audit with the notebook, then:\n")
cat("  Rscript scripts/make-figures.R\n")
