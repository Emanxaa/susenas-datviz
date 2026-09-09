cat("Testing syntax of updated intermediate scripts...\n")
files <- list.files("R/intermediate", pattern = "\\.R$", full.names = TRUE)
for (f in files) {
  cat("Checking parse:", basename(f), "...")
  p <- parse(f)
  cat(" OK (", length(p), " expressions)\n", sep = "")
}
cat("\nALL 4 SCRIPTS PARSED CLEANLY!\n")
