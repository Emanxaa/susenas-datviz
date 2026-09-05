# ==============================================================================
# SCRIPT EKSPOR HASIL ANALISIS SUSENAS JAWA BARAT 2023
# File: export_script_r/export_script_r.R
# Topik: Analisis Ketahanan Pangan (Pangsa Pengeluaran & Gizi) Berdasarkan Pendidikan KRT
# Framework: R + SQLite (DBI & RSQLite) + tidyverse + ggplot2
# ==============================================================================

# 1. Inisialisasi Direktori & Pemuatan Dependensi
# ------------------------------------------------------------------------------
script_dir <- tryCatch({
  # Jika dijalankan via Rscript
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    normalizePath(dirname(sub("--file=", "", file_arg)))
  } else {
    # Jika dijalankan secara interaktif
    if (dir.exists("export_script_r")) normalizePath("export_script_r") else getwd()
  }
}, error = function(e) getwd())

# Pastikan path ke R/utils.R terdeteksi baik dari root maupun dari subfolder
utils_path <- file.path(dirname(script_dir), "R", "utils.R")
if (!file.exists(utils_path)) {
  utils_path <- file.path(getwd(), "R", "utils.R")
}
if (!file.exists(utils_path)) {
  utils_path <- "R/utils.R"
}
source(utils_path)

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(tibble)
  library(ggplot2)
  library(scales)
  library(readr)
})

message(">> [1/5] Menginisialisasi koneksi basis data SQLite...")
con_susenas <- get_susenas_con()
con_metadata <- get_metadata_con()

on.exit({
  if (exists("con_susenas") && dbIsValid(con_susenas)) dbDisconnect(con_susenas)
  if (exists("con_metadata") && dbIsValid(con_metadata)) dbDisconnect(con_metadata)
}, add = TRUE)

# Output directory dipastikan di folder export_script_r
out_dir <- script_dir
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
}

# 2. Ambil Kamus Label Nilai Resmi dari metadata.db
# ------------------------------------------------------------------------------
message(">> [2/5] Mengambil kamus metadata dan label resmi dari metadata.db...")
lbls_edu <- as_tibble(dbGetQuery(con_metadata, "
  SELECT CAST(value AS INTEGER) AS kode_pendidikan, label AS nama_jenjang_resmi
  FROM value_labels
  WHERE variable = 'R612' AND year = 2023
  ORDER BY kode_pendidikan ASC;
"))

# 3. Kueri SQL Terbobot di SQLite (Heavy Lifting)
# ------------------------------------------------------------------------------
message(">> [3/5] Mengeksekusi kueri SQL tertimbang pada database/susenas.db...")

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
  END AS kategori_pendidikan,
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
GROUP BY 1
ORDER BY 1 ASC;
"
df_kebijakan <- as_tibble(dbGetQuery(con_susenas, sql_kebijakan))

# Kueri 2: Agregasi Rinci per Jenjang Kode Kuesioner Resmi (R612)
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
df_rinci_raw <- as_tibble(dbGetQuery(con_susenas, sql_rinci))

# Hubungkan dengan kamus label nilai resmi
df_rinci <- df_rinci_raw %>%
  left_join(lbls_edu, by = "kode_pendidikan") %>%
  mutate(
    nama_jenjang_resmi = case_when(
      kode_pendidikan == 0 ~ "Tidak/Belum Pernah Sekolah",
      TRUE ~ nama_jenjang_resmi
    )
  ) %>%
  select(kode_pendidikan, nama_jenjang_resmi, everything())

# Kueri 3: Ringkasan Total Provinsi Jawa Barat (Benchmark)
sql_total <- "
SELECT 
  'Jawa Barat (Total)' AS lingkup_wilayah,
  COUNT(*) AS total_sampel_rt,
  ROUND(SUM(PENIMBANG_RT), 0) AS total_estimasi_populasi_rt,
  ROUND(SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_pengeluaran_makanan,
  ROUND(SUM(TOTAL_PENGELUARAN * PENIMBANG_RT) / SUM(PENIMBANG_RT), 0) AS rerata_total_pengeluaran,
  ROUND((SUM(PENGELUARAN_MAKANAN * PENIMBANG_RT) / SUM(TOTAL_PENGELUARAN * PENIMBANG_RT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(KALORI_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_kalori_perkapita_hari,
  ROUND(SUM(PROTEIN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT), 1) AS rerata_protein_perkapita_hari
FROM v_head_household_welfare_2023
WHERE TOTAL_PENGELUARAN > 0 AND PENGELUARAN_MAKANAN > 0 AND PENIMBANG_RT > 0;
"
df_total <- as_tibble(dbGetQuery(con_susenas, sql_total))

# Tambahkan proporsi populasi pada df_kebijakan
df_kebijakan <- df_kebijakan %>%
  mutate(
    proporsi_populasi_persen = round(estimasi_populasi_rt * 100.0 / sum(estimasi_populasi_rt), 2),
    label_grafik = paste0(pangsa_pangan_persen, "%")
  )

# 4. Pembuatan Grafik Publikasi ggplot2 (Publication-Grade)
# ------------------------------------------------------------------------------
message(">> [4/5] Membuat visualisasi standar publikasi ilmiah dengan ggplot2...")

# Grafik 1: Pangsa Pengeluaran Makanan (Engel's Law)
p_engel <- ggplot(df_kebijakan, aes(x = kategori_pendidikan, y = pangsa_pangan_persen, fill = pangsa_pangan_persen)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(aes(label = label_grafik), vjust = -0.5, fontface = "bold", size = 4.2) +
  scale_y_continuous(limits = c(0, 75), labels = label_percent(scale = 1)) +
  scale_fill_gradient(low = "#2A9D8F", high = "#E76F51") +
  labs(
    title = "Pangsa Pengeluaran Makanan Berdasarkan Pendidikan Kepala Rumah Tangga",
    subtitle = "Bukti Empiris Hukum Engel di Provinsi Jawa Barat (SUSENAS 2023)",
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

# Grafik 2: Kecukupan Gizi Makro (Kalori & Protein) vs Garis Standar WNPG
df_gizi_long <- df_kebijakan %>%
  select(kategori_pendidikan, rerata_kalori_perkapita_hari, rerata_protein_perkapita_hari) %>%
  tidyr::pivot_longer(
    cols = c(rerata_kalori_perkapita_hari, rerata_protein_perkapita_hari),
    names_to = "indikator_gizi",
    values_to = "nilai_asupan"
  ) %>%
  mutate(
    indikator_label = ifelse(
      indikator_gizi == "rerata_kalori_perkapita_hari", 
      "Konsumsi Energi Kalori (Standar: 2.100 Kkal)", 
      "Konsumsi Protein (Standar: 57 Gram)"
    ),
    garis_baku = ifelse(indikator_gizi == "rerata_kalori_perkapita_hari", 2100, 57)
  )

p_gizi <- ggplot(df_gizi_long, aes(x = kategori_pendidikan, y = nilai_asupan, fill = kategori_pendidikan)) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_hline(aes(yintercept = garis_baku), linetype = "dashed", color = "#D62828", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.1f", nilai_asupan)), vjust = -0.4, fontface = "bold", size = 3.6) +
  facet_wrap(~indikator_label, scales = "free_y", ncol = 1) +
  scale_fill_brewer(palette = "Set2") +
  labs(
    title = "Kecukupan Asupan Kalori dan Protein per Kapita Sehari Menurut Pendidikan KRT",
    subtitle = "Garis merah putus-putus menunjukkan ambang batas kecukupan gizi WNPG (2.100 Kkal & 57 Gram)",
    x = "Jenjang Pendidikan KRT",
    y = "Rerata Asupan per Kapita Sehari",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2023 (KOR & Modul KP, Terbobot WERT)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(color = "gray30", margin = margin(b = 10)),
    axis.text.x = element_text(angle = 12, hjust = 1),
    strip.text = element_text(face = "bold", size = 11),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(face = "italic", color = "gray40", margin = margin(t = 12))
  )

# 5. Ekspor Seluruh Berkas Hasil ke Direktori export_script_r/
# ------------------------------------------------------------------------------
message(">> [5/5] Mengekspor seluruh file hasil ke direktori: ", out_dir)

file_csv_kebijakan <- file.path(out_dir, "tabel_ketahanan_pangan_kebijakan.csv")
file_csv_rinci     <- file.path(out_dir, "tabel_ketahanan_pangan_rinci.csv")
file_csv_total     <- file.path(out_dir, "ringkasan_indikator_jabar.csv")
file_rds_lengkap   <- file.path(out_dir, "hasil_analisis_lengkap.rds")
file_png_engel     <- file.path(out_dir, "grafik_pangsa_pangan_pendidikan.png")
file_png_gizi      <- file.path(out_dir, "grafik_kecukupan_gizi_pendidikan.png")

# Simpan Tabel CSV
write_csv(df_kebijakan, file_csv_kebijakan)
write_csv(df_rinci, file_csv_rinci)
write_csv(df_total, file_csv_total)

# Simpan RDS Bundle (untuk analisis lanjut di R / Quarto)
saveRDS(list(
  kebijakan = df_kebijakan,
  rinci = df_rinci,
  benchmark_total = df_total,
  plot_engel = p_engel,
  plot_gizi = p_gizi
), file_rds_lengkap)

# Simpan Grafik PNG Publikasi
ggsave(file_png_engel, plot = p_engel, width = 8.5, height = 5.2, dpi = 300)
ggsave(file_png_gizi, plot = p_gizi, width = 8.5, height = 7.0, dpi = 300)

message("==============================================================================")
message(">> EKSPOR BERHASIL DISELESAIKAN!")
message(">> Berkas yang dihasilkan di folder [", out_dir, "]:")
message("   1. Dataframe Kebijakan (CSV) : ", basename(file_csv_kebijakan))
message("   2. Dataframe Rinci (CSV)     : ", basename(file_csv_rinci))
message("   3. Benchmark Total Jabar (CSV: ", basename(file_csv_total))
message("   4. Bundle RDS Lengkap (RDS)  : ", basename(file_rds_lengkap))
message("   5. Grafik Pangsa Pangan (PNG): ", basename(file_png_engel))
message("   6. Grafik Kecukupan Gizi (PNG: ", basename(file_png_gizi))
message("==============================================================================")

# Tampilkan ringkasan dataframe kebijakan ke konsol
cat("\n=== RINGKASAN DATA KETAHANAN PANGAN JAWA BARAT (2023) ===\n")
print(as.data.frame(df_kebijakan[, c("kategori_pendidikan", "n_sampel_rt", "estimasi_populasi_rt", "pangsa_pangan_persen", "rerata_kalori_perkapita_hari", "rerata_protein_perkapita_hari")]))
cat("\n")
