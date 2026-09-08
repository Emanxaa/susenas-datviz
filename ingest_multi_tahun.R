#!/usr/bin/env Rscript
# ==============================================================================
# ingest_multi_tahun.R
# Lazy multi-year SUSENAS ingest - mencari data di semua lokasi yang diketahui
# tanpa membaca isi file CSV secara langsung (hemat token & RAM)
#
# Cara pakai:
#   Rscript ingest_multi_tahun.R
#   atau dari dalam R: source("ingest_multi_tahun.R")
#
# Data yang sudah tersedia:
#   - 2020 KP BP4.1 (CSV) - Jawa Barat/2020/csv/
#   - 2021 KP BP4.1 (CSV) - Jawa Barat/2021/csv/
#   - 2022 KP BP4.1 (DBF) - Jawa Barat/2022/dbf/
#   - 2023 KOR+KP (CSV)   - SUSENAS/JAWA BARAT/2023/csv/  [sudah di-ingest]
# ==============================================================================

# Path Setup (environment-aware)
if (Sys.getenv("COLAB_BACKEND_URL") != "") {
  ROOT_DIR <- tryCatch(system("find /content -name 'susenas-datviz.Rproj' -maxdepth 4 | head -1 | xargs dirname", intern = TRUE)[1],
                       error = function(e) "/content/susenas-datviz")
} else {
  ROOT_DIR <- tryCatch(here::here(), error = function(e) getwd())
}
setwd(ROOT_DIR)
message(">> ROOT_DIR: ", ROOT_DIR)

# Load utilities
source("R/utils.R")
source("R/03_import_sqlite.R")

# Kandidat lokasi folder data per tahun
# Pipeline mencari di urutan prioritas: SUSENAS/ terlebih dulu, lalu Jawa Barat/
DATA_ROOTS <- c(
  file.path(ROOT_DIR, "SUSENAS", "JAWA BARAT"),
  file.path(ROOT_DIR, "Jawa Barat")
)

# Helper: temukan root data untuk tahun tertentu
find_data_root <- function(year) {
  for (root in DATA_ROOTS) {
    yr_dir <- file.path(root, year)
    if (dir.exists(yr_dir)) {
      csv_count <- length(list.files(file.path(yr_dir, "csv"),
                                     pattern = "\\.csv$", recursive = TRUE))
      dbf_count <- length(list.files(file.path(yr_dir, "dbf"),
                                     pattern = "\\.dbf$", recursive = TRUE))
      if ((csv_count + dbf_count) > 0) {
        message(sprintf("   [%d] Ditemukan di: %s (CSV=%d, DBF=%d)",
                        year, root, csv_count, dbf_count))
        return(root)
      }
    }
  }
  message(sprintf("   [%d] Tidak ada data ditemukan di semua lokasi.", year))
  return(NULL)
}

# Ingest per tahun
YEARS_TO_INGEST <- c(2019, 2020, 2021, 2022)

message("\n======================================================================")
message("  SUSENAS Multi-Tahun Lazy Ingest - Jawa Barat")
message("======================================================================")

# Cek tabel yang sudah ada di SQLite
con_check <- get_susenas_con()
existing_tables <- dbListTables(con_check)
dbDisconnect(con_check)
message("\nTabel yang sudah ada di susenas.db:")
message("  ", paste(sort(existing_tables), collapse = ", "))

ingest_results <- list()

for (yr in YEARS_TO_INGEST) {
  # Skip jika sudah ada tabel untuk tahun ini
  yr_tables <- existing_tables[grepl(paste0("_", yr, "$"), existing_tables)]
  if (length(yr_tables) >= 1) {
    message(sprintf("\n[%d] Skip - tabel sudah ada: %s", yr, paste(yr_tables, collapse=", ")))
    next
  }

  # Cari data root
  found_root <- find_data_root(yr)
  if (is.null(found_root)) {
    message(sprintf("\n[%d] Skip - tidak ada data tersedia.", yr))
    next
  }

  message(sprintf("\n[%d] Memulai ingest dari: %s/%d/", yr, found_root, yr))

  result <- tryCatch(
    import_susenas_year(year = yr, susenas_root = found_root, force = FALSE),
    error = function(e) {
      message(sprintf("   ERROR pada tahun %d: %s", yr, e$message))
      return(NULL)
    }
  )

  ingest_results[[as.character(yr)]] <- result
}

# Ringkasan akhir
message("\n======================================================================")
message("  RINGKASAN INGEST")
message("======================================================================")

con_final <- get_susenas_con()
final_tables <- dbListTables(con_final)
dbDisconnect(con_final)

all_years <- as.character(2019:2023)
for (yr in all_years) {
  yr_tbls <- sort(final_tables[grepl(paste0("_", yr, "$"), final_tables)])
  status <- if (length(yr_tbls) > 0) paste0("OK (", paste(yr_tbls, collapse=", "), ")") else "-- tidak tersedia"
  message(sprintf("  %s: %s", yr, status))
}

message("\n>> Selesai. Database: database/susenas.db")
message(">> Jalankan export_komparasi_swasembada.R untuk analisis multi-tahun.\n")