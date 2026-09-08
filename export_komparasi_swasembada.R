# ==============================================================================
# WRAPPER: export_komparasi_swasembada.R
# Menjalankan evaluasi status rawan pangan sebelum vs setelah swasembada pangan
# ==============================================================================

target_script <- file.path("export_script_r", "export_komparasi_swasembada_2019_2023.R")
if (file.exists(target_script)) {
  source(target_script)
} else {
  stop("Berkas tidak ditemukan: ", target_script)
}
