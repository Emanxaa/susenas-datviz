# ==============================================================================
# WRAPPER: export_script_r.R
# Menjalankan skrip ekspor utama di folder export_script_r/
# ==============================================================================

target_script <- file.path("export_script_r", "export_script_r.R")
if (file.exists(target_script)) {
  source(target_script)
} else {
  stop("File tidak ditemukan: ", target_script)
}
