# ==============================================================================
# WRAPPER: export_rawan_pangan_2023.R
# Menjalankan skrip utama Identifikasi Daerah Rawan Pangan di export_script_r/
# ==============================================================================

target_script <- file.path("export_script_r", "export_rawan_pangan_2023.R")
if (file.exists(target_script)) {
  source(target_script)
} else {
  stop("Berkas tidak ditemukan: ", target_script)
}
