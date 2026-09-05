# ==============================================================================
# UNIVERSAL SUSENAS R PIPELINE (ENVIRONMENT-AWARE)
# Mendukung eksekusi tanpa modifikasi manual pada:
# 1. RStudio Project (Local / Server)
# 2. Google Colab (IRkernel / %%R)
# ------------------------------------------------------------------------------
# Aturan Utama:
# - Menggunakan satu variabel ROOT_DIR untuk seluruh resolusi berkas.
# - Seluruh path dibangun dengan file.path().
# - Semua koneksi database menggunakan helper di R/utils.R.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT DETECTION & ROOT_DIR RESOLUTION
# ------------------------------------------------------------------------------
message(">> [Step 1/10] Mendeteksi runtime environment & mengidentifikasi ROOT_DIR...")

is_colab <- dir.exists("/content") || 
            nzchar(Sys.getenv("COLAB_RELEASE_TAG")) || 
            nzchar(Sys.getenv("COLAB_GPU"))

is_rstudio <- nzchar(Sys.getenv("RSTUDIO")) || 
              (exists(".rs.api") && !is.null(get(".rs.api")))

# Mount Google Drive jika berada di Google Colab dan belum terpasang
if (is_colab && !dir.exists("/content/drive/MyDrive")) {
  message("   [Colab] Memasang (mounting) Google Drive...")
  tryCatch({
    system("python3 -c 'from google.colab import drive; drive.mount(\"/content/drive\")'")
  }, error = function(e) {
    message("   [Colab] Perhatian: Mount Google Drive otomatis dilewati atau gagal: ", e$message)
  })
}

# Algoritma pencarian ROOT_DIR otomatis
find_project_root <- function() {
  # 1. Cek package 'here' jika tersedia
  if (requireNamespace("here", quietly = TRUE)) {
    h_root <- tryCatch(here::here(), error = function(e) NULL)
    if (!is.null(h_root) && file.exists(file.path(h_root, "database", "metadata.db"))) {
      return(normalizePath(h_root, winslash = "/"))
    }
  }
  
  # 2. Telusuri direktori saat ini dan hirarki parent ke atas
  curr <- getwd()
  for (i in 1:6) {
    if (file.exists(file.path(curr, "database", "metadata.db")) || 
        file.exists(file.path(curr, "AGENTS.md"))) {
      return(normalizePath(curr, winslash = "/"))
    }
    parent <- dirname(curr)
    if (parent == curr) break
    curr <- parent
  }
  
  # 3. Kandidat direktori khusus lingkungan Google Colab
  if (is_colab) {
    colab_candidates <- c(
      "/content/susenas-datviz",
      "/content/SUSENAS",
      "/content/drive/MyDrive/susenas-datviz",
      "/content/drive/MyDrive/SUSENAS",
      "/content"
    )
    for (cand in colab_candidates) {
      if (dir.exists(cand) && 
          (file.exists(file.path(cand, "database", "metadata.db")) || 
           file.exists(file.path(cand, "AGENTS.md")))) {
        return(normalizePath(cand, winslash = "/"))
      }
    }
  }
  
  # Fallback: Direktori kerja aktif
  normalizePath(getwd(), winslash = "/")
}

ROOT_DIR <- find_project_root()
setwd(ROOT_DIR)

ENV_NAME <- if (is_colab) "Google Colab" else if (is_rstudio) "RStudio Project" else "Local / Terminal R"

cat("----------------------------------------------------------------------\n")
cat(">> Environment Terdeteksi :", ENV_NAME, "\n")
cat(">> Project ROOT_DIR       :", ROOT_DIR, "\n")
cat("----------------------------------------------------------------------\n")

# ------------------------------------------------------------------------------
# 2. LOAD PACKAGES
# ------------------------------------------------------------------------------
message(">> [Step 2/10] Memuat package yang dibutuhkan...")

required_packages <- c("DBI", "RSQLite", "dplyr", "tibble", "ggplot2", "scales", "readr", "tidyr")

# Instal otomatis package yang belum tersedia jika di Colab
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("   Menginstal package: ", pkg, " ...")
    install.packages(pkg, repos = "https://cloud.r-project.org", quiet = TRUE)
  }
}

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tibble)
  library(ggplot2)
  library(scales)
  library(readr)
  library(tidyr)
})

# ------------------------------------------------------------------------------
# 3. SOURCE R/utils.R
# ------------------------------------------------------------------------------
message(">> [Step 3/10] Memuat fungsi utilitas dari R/utils.R...")

utils_file <- file.path(ROOT_DIR, "R", "utils.R")
if (!file.exists(utils_file)) {
  stop("File utilitas tidak ditemukan pada: ", utils_file)
}
source(utils_file)

# ------------------------------------------------------------------------------
# 4. CONNECT SQLITE (MENGGUNAKAN HELPER RESMI)
# ------------------------------------------------------------------------------
message(">> [Step 4/10] Membuka koneksi basis data SQLite melalui helper R/utils.R...")

con_susenas  <- get_susenas_con(file.path(ROOT_DIR, "database", "susenas.db"))
con_metadata <- get_metadata_con(file.path(ROOT_DIR, "database", "metadata.db"))

# Pastikan koneksi selalu tertutup saat script selesai / error
on.exit({
  if (exists("con_susenas") && dbIsValid(con_susenas)) {
    dbDisconnect(con_susenas)
    message(">> [Step 10/10] Koneksi database/susenas.db berhasil ditutup.")
  }
  if (exists("con_metadata") && dbIsValid(con_metadata)) {
    dbDisconnect(con_metadata)
    message(">> [Step 10/10] Koneksi database/metadata.db berhasil ditutup.")
  }
}, add = TRUE)

# ------------------------------------------------------------------------------
# 5. GENERATE SQL (HEAVY LIFTING DI SQLITE ENGINE)
# ------------------------------------------------------------------------------
message(">> [Step 5/10] Membangun kueri SQL teroptimasi dengan pembobotan sampling WERT...")

# Kueri 1: Agregasi Tingkat Kebijakan (5 Kategori Standar BPS)
sql_kebijakan <- "
SELECT 
  CASE 
    WHEN PENDIDIKAN_TERTINGGI_KRT = 0 THEN '1. Tidak/Belum Pernah Sekolah'
    WHEN PENDIDIKAN_TERTINGGI_KRT BETWEEN 1 AND 5 THEN '2. SD / Sederajat'
    WHEN PENDIDIKAN_TERTINGGI_KRT BETWEEN 6 AND 10 THEN '3. SMP / Sederajat'
    WHEN PENDIDIKAN_TERTINGGI_KRT BETWEEN 11 AND 17 THEN '4. SMA / SMK / Sederajat'
    WHEN PENDIDIKAN_TERTINGGI_KRT >= 18 THEN '5. Perguruan Tinggi (Diploma/Sarjana)'
    ELSE 'Lainnya'
  END AS kategori_kebijakan,
  COUNT(*) AS n_sampel_rt,
  ROUND(SUM(PENIMBANG_RT), 0) AS estimasi_populasi_rt,
  ROUND(SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_pengeluaran_makanan,
  ROUND(SUM(TOTAL_PENGELUARAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_total_pengeluaran,
  ROUND((SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(TOTAL_PENGELUARAN * PENIMBANG_RT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(KALORI_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_kalori_perkapita_hari,
  ROUND(SUM(PROTEIN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_protein_perkapita_hari
FROM v_head_household_welfare_2023
WHERE TOTAL_PENGELUARAN > 0 
  AND PENGELUARAN_MAKANAN > 0 
  AND PENIMBANG_RT > 0
  AND PENDIDIKAN_TERTINGGI_KRT IS NOT NULL
GROUP BY 1
ORDER BY 1 ASC;
"

# Kueri 2: Rincian per Jenjang Kode Kuesioner (R612)
sql_rinci <- "
SELECT 
  PENDIDIKAN_TERTINGGI_KRT AS kode_pendidikan,
  COUNT(*) AS n_sampel_rt,
  ROUND(SUM(PENIMBANG_RT), 0) AS estimasi_populasi_rt,
  ROUND(SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_pengeluaran_makanan_rt,
  ROUND(SUM(TOTAL_PENGELUARAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_total_pengeluaran_rt,
  ROUND((SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(TOTAL_PENGELUARAN * PENIMBANG_RT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(KALORI_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_kalori_perkapita_hari,
  ROUND(SUM(PROTEIN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_protein_perkapita_hari
FROM v_head_household_welfare_2023
WHERE TOTAL_PENGELUARAN > 0 
  AND PENGELUARAN_MAKANAN > 0 
  AND PENIMBANG_RT > 0
  AND PENDIDIKAN_TERTINGGI_KRT IS NOT NULL
GROUP BY PENDIDIKAN_TERTINGGI_KRT
ORDER BY PENDIDIKAN_TERTINGGI_KRT ASC;
"

# ------------------------------------------------------------------------------
# 6. EXECUTE QUERY
# ------------------------------------------------------------------------------
message(">> [Step 6/10] Mengeksekusi query agregasi terhadap susenas.db...")
raw_kebijakan <- as_tibble(dbGetQuery(con_susenas, sql_kebijakan))
raw_rinci     <- as_tibble(dbGetQuery(con_susenas, sql_rinci))

# ------------------------------------------------------------------------------
# 7. APPLY OFFICIAL VALUE LABELS DARI metadata.db
# ------------------------------------------------------------------------------
message(">> [Step 7/10] Menerapkan label nilai resmi dari value_labels (metadata.db)...")

lbls_edu <- as_tibble(dbGetQuery(con_metadata, "
  SELECT CAST(value AS INTEGER) AS kode_pendidikan, label AS label_jenjang_resmi
  FROM value_labels
  WHERE variable = 'R612' AND year = 2023
  ORDER BY kode_pendidikan ASC;
"))

labeled_rinci <- raw_rinci %>%
  left_join(lbls_edu, by = "kode_pendidikan") %>%
  mutate(
    label_jenjang_resmi = case_when(
      kode_pendidikan == 0 ~ "Tidak/Belum Pernah Sekolah",
      TRUE ~ label_jenjang_resmi
    )
  ) %>%
  select(kode_pendidikan, label_jenjang_resmi, everything())

# ------------------------------------------------------------------------------
# 8. CLEAN MISSING VALUES & PERSIAPAN DATAFRAME ANALISIS
# ------------------------------------------------------------------------------
message(">> [Step 8/10] Memvalidasi kelengkapan data & menghitung proporsi populasi...")

clean_policy_df <- raw_kebijakan %>%
  filter(!is.na(kategori_kebijakan), estimasi_populasi_rt > 0) %>%
  mutate(
    proporsi_populasi_rt_persen = round(estimasi_populasi_rt * 100.0 / sum(estimasi_populasi_rt), 2),
    label_grafik = paste0(pangsa_pangan_persen, "%")
  )

# Buat visualisasi ggplot2 standar publikasi
p_engel <- ggplot(clean_policy_df, aes(x = kategori_kebijakan, y = pangsa_pangan_persen, fill = pangsa_pangan_persen)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = label_grafik), vjust = -0.5, fontface = "bold", size = 4.2) +
  scale_y_continuous(limits = c(0, 75), labels = label_percent(scale = 1)) +
  scale_fill_gradient(low = "#2A9D8F", high = "#E76F51") +
  labs(
    title = "Pangsa Pengeluaran Makanan Berdasarkan Pendidikan Kepala Rumah Tangga",
    subtitle = paste0("Bukti Empiris Hukum Engel di Jawa Barat (SUSENAS 2023) | Environment: ", ENV_NAME),
    x = "Jenjang Pendidikan KRT",
    y = "Pangsa Pengeluaran Pangan (%)",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2023 (KOR & Modul KP, Terbobot WERT)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(color = "gray30", margin = margin(b = 10)),
    axis.text.x = element_text(angle = 15, hjust = 1, face = "bold"),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(face = "italic", color = "gray40", margin = margin(t = 12))
  )

# ------------------------------------------------------------------------------
# 9. EXPORT HASIL (MENYIMPAN KE ROOT_DIR/output/)
# ------------------------------------------------------------------------------
message(">> [Step 9/10] Mengekspor hasil analisis ke direktori output...")

output_dir <- file.path(ROOT_DIR, "output")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

file_csv_kebijakan <- file.path(output_dir, "tabel_analisis_ketahanan_pangan.csv")
file_csv_rinci     <- file.path(output_dir, "tabel_pendidikan_rinci.csv")
file_plot_png      <- file.path(output_dir, "grafik_pangsa_pangan_universal.png")
file_bundle_rds    <- file.path(output_dir, "hasil_analisis_universal.rds")

write_csv(clean_policy_df, file_csv_kebijakan)
write_csv(labeled_rinci, file_csv_rinci)
ggsave(file_plot_png, plot = p_engel, width = 8.5, height = 5.2, dpi = 300)

saveRDS(list(
  environment = ENV_NAME,
  root_dir = ROOT_DIR,
  tabel_kebijakan = clean_policy_df,
  tabel_rinci = labeled_rinci,
  plot = p_engel
), file_bundle_rds)

message("======================================================================")
message(">> PIPELINE UNIVERSAL SELESAI DIEKSEKUSI SECARA SUKSES!")
message(">> File output yang dihasilkan di: ", output_dir)
message("   1. ", basename(file_csv_kebijakan))
message("   2. ", basename(file_csv_rinci))
message("   3. ", basename(file_plot_png))
message("   4. ", basename(file_bundle_rds))
message("======================================================================")

# ------------------------------------------------------------------------------
# 10. TUTUP KONEKSI (DIATUR OLEH on.exit DI STEP 4)
# ------------------------------------------------------------------------------
# Koneksi tertutup otomatis dan terkonfirmasi di on.exit()

# Tampilkan ringkasan tabel ke output
print(as.data.frame(clean_policy_df))
