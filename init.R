# ==============================================================================
# ONBOARDING BOOTSTRAP: init.R
# Script inisialisasi lingkungan kerja untuk rekan tim / kolaborator baru
# Jalankan script ini pertama kali setelah melakukan clone repository:
#   source("init.R")
# ==============================================================================

cat("======================================================================\n")
cat("   SUSENAS Research & Data Visualization Framework (Bootstrap)\n")
cat("   Inisialisasi Lingkungan Kerja Kolaborator & Pengecekan Sistem\n")
cat("======================================================================\n\n")

# 1. Pengecekan Versi R
# ------------------------------------------------------------------------------
r_major <- as.integer(R.version$major)
r_minor <- as.numeric(strsplit(R.version$minor, "\\.")[[1]][1])
cat(">> [1/5] Pengecekan Versi R:\n")
cat(sprintf("   R version: %s.%s (%s)\n", R.version$major, R.version$minor, R.version$platform))
if (r_major < 4 || (r_major == 4 && r_minor < 2)) {
  warning("Versi R direkomendasikan >= 4.2.0. Beberapa package mungkin memerlukan update.")
} else {
  cat("   [OK] Versi R memenuhi syarat (>= 4.2.0).\n")
}

# 2. Pengecekan dan Instalasi Package Dependensi
# ------------------------------------------------------------------------------
cat("\n>> [2/5] Pengecekan dan Instalasi Package Dependensi:\n")
required_packages <- c(
  "DBI", "RSQLite", "dplyr", "tibble", "tidyr", "stringr", "purrr", "forcats",
  "readr", "readxl", "data.table", "ggplot2", "scales", "jsonlite", "here"
)

installed_pkgs <- rownames(installed.packages())
missing_pkgs   <- setdiff(required_packages, installed_pkgs)

if (length(missing_pkgs) > 0) {
  cat(sprintf("   Ditemukan %d package yang belum terinstal: %s\n", length(missing_pkgs), paste(missing_pkgs, collapse = ", ")))
  cat("   Mengunduh dan menginstal dari CRAN cloud repository...\n")
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org", quiet = FALSE)
  cat("   [OK] Seluruh package berhasil diinstal.\n")
} else {
  cat("   [OK] Seluruh package yang dibutuhkan telah terinstal lengkap.\n")
}

# 3. Pengecekan Struktur Direktori Proyek
# ------------------------------------------------------------------------------
cat("\n>> [3/5] Pengecekan Struktur Direktori Proyek:\n")
required_dirs <- c(
  "database", "R", "output", "quarto", "export_script_r",
  file.path("SUSENAS", "JAWA BARAT")
)

for (d in required_dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    cat(sprintf("   + Membuat direktori: %s\n", d))
  } else {
    cat(sprintf("   [OK] Direktori ada: %s\n", d))
  }
}

# 4. Pengecekan Basis Data SQLite
# ------------------------------------------------------------------------------
cat("\n>> [4/5] Pengecekan Basis Data SQLite (database/):\n")

meta_db_path <- file.path("database", "metadata.db")
suse_db_path <- file.path("database", "susenas.db")

meta_exists <- file.exists(meta_db_path)
suse_exists <- file.exists(suse_db_path)

if (meta_exists) {
  meta_size_mb <- round(file.size(meta_db_path) / (1024 * 1024), 2)
  cat(sprintf("   [OK] metadata.db terdeteksi (%s MB)\n", meta_size_mb))
} else {
  cat("   [!] metadata.db belum ada. Membangun metadata dari script setup...\n")
  tryCatch({
    source("R/00_setup.R")
    source("R/01_build_catalog.R")
    source("R/02_build_registry.R")
    source("R/04_build_semantic_registry.R")
    cat("   [OK] metadata.db berhasil dibangun secara otomatis.\n")
  }, error = function(e) {
    cat("   [PERHATIAN] Gagal membangun metadata.db: ", e$message, "\n")
  })
}

if (suse_exists) {
  suse_size_mb <- round(file.size(suse_db_path) / (1024 * 1024), 2)
  cat(sprintf("   [OK] susenas.db terdeteksi (%s MB)\n", suse_size_mb))
} else {
  cat("   [PERHATIAN] susenas.db belum tersedia di database/.\n")
  cat("   -> Harap pastikan raw data CSV berada di SUSENAS/JAWA BARAT/2023/csv/\n")
  cat("   -> Lalu jalankan: Rscript R/03_import_sqlite.R\n")
  cat("   -> Atau unduh database dari Google Drive tim.\n")
}

# 5. Uji Coba Pemuatan Modul Utilitas R/utils.R
# ------------------------------------------------------------------------------
cat("\n>> [5/5] Uji Coba Pemuatan Modul Utilitas R/utils.R:\n")
tryCatch({
  source("R/utils.R")
  if (meta_exists) {
    con_test <- get_metadata_con()
    n_vars <- dbGetQuery(con_test, "SELECT COUNT(*) as n FROM variable_registry")$n
    dbDisconnect(con_test)
    cat(sprintf("   [OK] R/utils.R berfungsi optimal. Terindeks %d variabel resmi.\n", n_vars))
  } else {
    cat("   [OK] R/utils.R berhasil dimuat.\n")
  }
}, error = function(e) {
  cat("   [GAGAL] Pemuatan R/utils.R mengalami kendala: ", e$message, "\n")
})

cat("\n======================================================================\n")
cat(">> STATUS BOOTSTRAP: PROYEK SIAP DIGUNAKAN OLEH REKAN TIM!\n")
cat(">> Langkah Selanjutnya untuk Kolaborator:\n")
cat("   1. Jalankan pipeline universal   : Rscript universal_pipeline.R\n")
cat("   2. Jalankan studi rawan pangan   : Rscript export_script_r/export_rawan_pangan_2023.R\n")
cat("   3. Buka dokumen panduan lengkap  : CONTRIBUTING.md atau README.md\n")
cat("======================================================================\n\n")
