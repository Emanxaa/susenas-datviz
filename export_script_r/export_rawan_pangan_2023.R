# ==============================================================================
# SCRIPT EKSPOR: IDENTIFIKASI DAERAH RAWAN PANGAN JAWA BARAT 2023
# File: export_script_r/export_rawan_pangan_2023.R
# Lingkup: 27 Kabupaten/Kota & Klasifikasi Desa/Kota (SUSENAS Jawa Barat 2023)
# Kompatibilitas: RStudio Project & Google Colab (Environment-Aware)
# Framework: R + SQLite (DBI & RSQLite) + tidyverse + ggplot2
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ENVIRONMENT DETECTION & ROOT_DIR RESOLUTION
# ------------------------------------------------------------------------------
message(">> [Step 1/8] Mendeteksi runtime environment & mengidentifikasi ROOT_DIR...")

is_colab <- dir.exists("/content") || 
            nzchar(Sys.getenv("COLAB_RELEASE_TAG")) || 
            nzchar(Sys.getenv("COLAB_GPU"))

is_rstudio <- nzchar(Sys.getenv("RSTUDIO")) || 
              (exists(".rs.api") && !is.null(get(".rs.api")))

if (is_colab && !dir.exists("/content/drive/MyDrive")) {
  message("   [Colab] Memasang (mounting) Google Drive...")
  tryCatch({
    system("python3 -c 'from google.colab import drive; drive.mount(\"/content/drive\")'")
  }, error = function(e) {
    message("   [Colab] Perhatian: Mount Google Drive otomatis dilewati/gagal: ", e$message)
  })
}

find_project_root <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    h_root <- tryCatch(here::here(), error = function(e) NULL)
    if (!is.null(h_root) && file.exists(file.path(h_root, "database", "metadata.db"))) {
      return(normalizePath(h_root, winslash = "/"))
    }
  }
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
  normalizePath(getwd(), winslash = "/")
}

ROOT_DIR <- find_project_root()
setwd(ROOT_DIR)

ENV_NAME <- if (is_colab) "Google Colab" else if (is_rstudio) "RStudio Project" else "Local / Terminal R"
cat(">> Environment Terdeteksi :", ENV_NAME, "\n")
cat(">> Project ROOT_DIR       :", ROOT_DIR, "\n")

# ------------------------------------------------------------------------------
# 2. LOAD PACKAGES & SOURCE UTILS
# ------------------------------------------------------------------------------
message(">> [Step 2/8] Memuat dependensi package & modul R/utils.R...")

required_packages <- c("DBI", "RSQLite", "dplyr", "tibble", "ggplot2", "scales", "readr", "tidyr", "forcats")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
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
  library(forcats)
})

source(file.path(ROOT_DIR, "R", "utils.R"))

# ------------------------------------------------------------------------------
# 3. CONNECT SQLITE DATABASES
# ------------------------------------------------------------------------------
message(">> [Step 3/8] Membuka koneksi basis data SQLite...")

con_susenas  <- get_susenas_con(file.path(ROOT_DIR, "database", "susenas.db"))
con_metadata <- get_metadata_con(file.path(ROOT_DIR, "database", "metadata.db"))

on.exit({
  if (exists("con_susenas") && dbIsValid(con_susenas)) dbDisconnect(con_susenas)
  if (exists("con_metadata") && dbIsValid(con_metadata)) dbDisconnect(con_metadata)
  message(">> [Step 8/8] Seluruh koneksi SQLite berhasil ditutup aman.")
}, add = TRUE)

# ------------------------------------------------------------------------------
# 4. QUERY SQL: IDENTIFIKASI RAWAN PANGAN (HEAVY LIFTING DI SQLITE)
# ------------------------------------------------------------------------------
message(">> [Step 4/8] Mengeksekusi kueri komprehensif indikator kerawanan pangan...")

# A. Kueri Tingkat Kabupaten/Kota (27 Daerah)
sql_kabkot <- "
SELECT 
  r.R102 AS kode_kabkot,
  COUNT(*) AS n_sampel_rt,
  ROUND(SUM(k.WERT), 0) AS estimasi_populasi_rt,
  
  -- 1. Dimensi Ekonomi & Beban Pangan (Engel's Law)
  ROUND(SUM(k.KAPITA * k.WERT) / SUM(k.WERT), 0) AS rerata_pengeluaran_kapita,
  ROUND(SUM(k.FOOD * k.WERT) / SUM(k.WERT), 0) AS rerata_pengeluaran_makanan_rt,
  ROUND(SUM(k.EXPEND * k.WERT) / SUM(k.WERT), 0) AS rerata_total_pengeluaran_rt,
  ROUND((SUM(k.FOOD * k.WERT) / SUM(k.EXPEND * k.WERT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(CASE WHEN (k.FOOD * 1.0 / k.EXPEND) > 0.60 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_pangsa_pangan_gt60,
  
  -- 2. Dimensi Asupan Gizi Makro (Kalori & Protein vs WNPG)
  ROUND(SUM(k.KALORI_KAP * k.WERT) / SUM(k.WERT), 1) AS rerata_kalori_kapita,
  ROUND(SUM(CASE WHEN k.KALORI_KAP < 2100 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_defisit_kalori,
  ROUND(SUM(CASE WHEN k.KALORI_KAP < 1700 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_defisit_kalori_berat,
  ROUND(SUM(k.PROTE_KAP * k.WERT) / SUM(k.WERT), 1) AS rerata_protein_kapita,
  ROUND(SUM(CASE WHEN k.PROTE_KAP < 57 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_defisit_protein,
  
  -- 3. Dimensi Pengalaman Kerawanan Pangan FIES (BPS / FAO)
  ROUND(SUM(CASE WHEN r.R1701 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_cemas_kurang_makan_r1701,
  ROUND(SUM(CASE WHEN r.R1706 = 1 OR r.R1707 = 1 OR r.R1708 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_kelaparan_akut_r1706_08,
  ROUND(SUM(CASE WHEN (
    (CASE WHEN r.R1701 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1702 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1703 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1704 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1705 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1706 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1707 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1708 = 1 THEN 1 ELSE 0 END)
  ) >= 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS prevalensi_fies_skor_ge1,
  
  -- 4. Dimensi Perlindungan Sosial (BPNT & PKH)
  ROUND(SUM(CASE WHEN r.R2207 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_bpnt_persen,
  ROUND(SUM(CASE WHEN r.R2204A = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_pkh_persen

FROM kor_rt_2023 r
INNER JOIN kp_bp43_2023 k ON r.URUT = k.URUT
WHERE k.EXPEND > 0 AND k.FOOD > 0 AND k.WERT > 0
GROUP BY r.R102
ORDER BY pangsa_pangan_persen DESC;
"
df_kabkot_raw <- as_tibble(dbGetQuery(con_susenas, sql_kabkot))

# B. Kueri Tingkat Wilayah Perkotaan vs Perdesaan
sql_desa_kota <- "
SELECT 
  CASE 
    WHEN r.R105 = 1 THEN 'Perkotaan' 
    WHEN r.R105 = 2 THEN 'Perdesaan' 
    ELSE 'Lainnya' 
  END AS tipe_wilayah,
  COUNT(*) AS n_sampel_rt,
  ROUND(SUM(k.WERT), 0) AS estimasi_populasi_rt,
  ROUND(SUM(k.KAPITA * k.WERT) / SUM(k.WERT), 0) AS rerata_pengeluaran_kapita,
  ROUND((SUM(k.FOOD * k.WERT) / SUM(k.EXPEND * k.WERT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(CASE WHEN (k.FOOD * 1.0 / k.EXPEND) > 0.60 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_pangsa_pangan_gt60,
  ROUND(SUM(k.KALORI_KAP * k.WERT) / SUM(k.WERT), 1) AS rerata_kalori_kapita,
  ROUND(SUM(CASE WHEN k.KALORI_KAP < 2100 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_defisit_kalori,
  ROUND(SUM(k.PROTE_KAP * k.WERT) / SUM(k.WERT), 1) AS rerata_protein_kapita,
  ROUND(SUM(CASE WHEN k.PROTE_KAP < 57 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_rt_defisit_protein,
  ROUND(SUM(CASE WHEN (
    (CASE WHEN r.R1701 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1702 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1703 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1704 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1705 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1706 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1707 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1708 = 1 THEN 1 ELSE 0 END)
  ) >= 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS prevalensi_fies_persen,
  ROUND(SUM(CASE WHEN r.R2207 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_bpnt_persen
FROM kor_rt_2023 r
INNER JOIN kp_bp43_2023 k ON r.URUT = k.URUT
WHERE k.EXPEND > 0 AND k.FOOD > 0 AND k.WERT > 0
GROUP BY r.R105;
"
df_desa_kota <- as_tibble(dbGetQuery(con_susenas, sql_desa_kota))

# ------------------------------------------------------------------------------
# 5. PELABELAN RESMI & PENYUSUNAN INDEKS KERAWANAN PANGAN KOMPOSIT
# ------------------------------------------------------------------------------
message(">> [Step 5/8] Menghitung Indeks Komposit Kerawanan Pangan & Ranking Prioritas...")

# Fungsi normalisasi min-max
min_max_scale <- function(x) {
  if (max(x) == min(x)) return(rep(0.5, length(x)))
  (x - min(x)) / (max(x) - min(x))
}

df_kabkot <- df_kabkot_raw %>%
  mutate(
    nama_kabkot = JABAR_KABKOT_NAMES[as.character(kode_kabkot)],
    nama_kabkot = ifelse(is.na(nama_kabkot), paste("Kab/Kota", kode_kabkot), nama_kabkot)
  ) %>%
  # Perhitungan Skor Komposit Kerawanan Pangan (Bobot: 40% Pangsa Pangan + 30% Defisit Kalori + 30% FIES)
  mutate(
    norm_pangsa_pangan = min_max_scale(pangsa_pangan_persen),
    norm_defisit_kalori = min_max_scale(pct_rt_defisit_kalori),
    norm_fies = min_max_scale(prevalensi_fies_skor_ge1),
    skor_kerawanan_komposit = round((0.40 * norm_pangsa_pangan + 0.30 * norm_defisit_kalori + 0.30 * norm_fies) * 100, 2)
  ) %>%
  arrange(desc(skor_kerawanan_komposit)) %>%
  mutate(
    ranking_kerawanan = row_number(),
    status_prioritas = case_when(
      ranking_kerawanan <= 5  ~ "Prioritas 1: Sangat Rawan",
      ranking_kerawanan <= 12 ~ "Prioritas 2: Rawan",
      ranking_kerawanan <= 19 ~ "Prioritas 3: Rentan",
      TRUE                    ~ "Prioritas 4: Tahan Pangan"
    )
  ) %>%
  select(
    ranking_kerawanan,
    status_prioritas,
    kode_kabkot,
    nama_kabkot,
    skor_kerawanan_komposit,
    pangsa_pangan_persen,
    pct_rt_pangsa_pangan_gt60,
    pct_rt_defisit_kalori,
    pct_rt_defisit_protein,
    prevalensi_fies_skor_ge1,
    pct_kelaparan_akut_r1706_08,
    cakupan_bpnt_persen,
    rerata_pengeluaran_kapita,
    n_sampel_rt,
    estimasi_populasi_rt
  )

# ------------------------------------------------------------------------------
# 6. VISUALISASI PUBLIKASI PUBLICATION-GRADE (GGPLOT2)
# ------------------------------------------------------------------------------
message(">> [Step 6/8] Membuat grafik visualisasi pemetaan daerah rawan pangan...")

# Grafik 1: Peringkat 27 Kabupaten/Kota Berdasarkan Skor Komposit Kerawanan
p_ranking <- ggplot(df_kabkot, aes(x = skor_kerawanan_komposit, y = fct_reorder(nama_kabkot, skor_kerawanan_komposit), fill = status_prioritas)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = sprintf("%.1f", skor_kerawanan_komposit)), hjust = -0.2, size = 3.2, fontface = "bold") +
  scale_x_continuous(limits = c(0, 105), expand = c(0, 0)) +
  scale_fill_manual(values = c(
    "Prioritas 1: Sangat Rawan" = "#B7094C",
    "Prioritas 2: Rawan"        = "#C75146",
    "Prioritas 3: Rentan"       = "#E09F3E",
    "Prioritas 4: Tahan Pangan" = "#2A9D8F"
  )) +
  labs(
    title = "Identifikasi Daerah Rawan Pangan Provinsi Jawa Barat 2023",
    subtitle = "Indeks Komposit: Pangsa Pangan (40%) + Prevalensi Defisit Kalori (30%) + Skor FIES (30%)",
    x = "Skor Indeks Kerawanan Pangan Komposit (0 - 100)",
    y = "Kabupaten / Kota",
    fill = "Klasifikasi Prioritas",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2023 (KOR & Modul KP, Terbobot WERT)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "gray30", size = 9.5, margin = margin(b = 10)),
    legend.position = "top",
    legend.title = element_text(face = "bold", size = 9),
    panel.grid.minor = element_blank(),
    plot.caption = element_text(face = "italic", color = "gray40", size = 8, margin = margin(t = 10))
  )

# Grafik 2: Matriks Kuadran Kerawanan (Pangsa Pangan vs Prevalensi FIES)
median_pangsa <- median(df_kabkot$pangsa_pangan_persen)
median_fies   <- median(df_kabkot$prevalensi_fies_skor_ge1)

p_matriks <- ggplot(df_kabkot, aes(x = pangsa_pangan_persen, y = prevalensi_fies_skor_ge1)) +
  geom_vline(xintercept = median_pangsa, linetype = "dashed", color = "gray50") +
  geom_hline(yintercept = median_fies, linetype = "dashed", color = "gray50") +
  geom_point(aes(size = estimasi_populasi_rt / 1000, color = status_prioritas), alpha = 0.85) +
  geom_text(aes(label = nama_kabkot), vjust = -0.7, size = 2.9, fontface = "bold", check_overlap = FALSE) +
  scale_color_manual(values = c(
    "Prioritas 1: Sangat Rawan" = "#B7094C",
    "Prioritas 2: Rawan"        = "#C75146",
    "Prioritas 3: Rentan"       = "#E09F3E",
    "Prioritas 4: Tahan Pangan" = "#2A9D8F"
  )) +
  scale_size_continuous(name = "Populasi RT (Ribu)", range = c(3, 9)) +
  scale_y_continuous(limits = c(0, 40)) +
  labs(
    title = "Matriks Kerawanan Pangan: Beban Ekonomi (Pangsa Pangan) vs Persepsi FIES",
    subtitle = "Garis putus-putus menunjukkan median Jawa Barat (Kuadran Kanan Atas: Zona Paling Rawan)",
    x = "Rerata Pangsa Pengeluaran Makanan (%)",
    y = "Prevalensi Kerawanan Pangan FIES (%)",
    color = "Status Prioritas",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2023 (KOR & Modul KP, Terbobot WERT)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "gray30", margin = margin(b = 10)),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

# Grafik 3: Kesenjangan Rawan Pangan Perkotaan vs Perdesaan
df_desa_kota_plot <- df_desa_kota %>%
  select(tipe_wilayah, pangsa_pangan_persen, pct_rt_defisit_kalori, pct_rt_defisit_protein, prevalensi_fies_persen, cakupan_bpnt_persen) %>%
  tidyr::pivot_longer(cols = -tipe_wilayah, names_to = "indikator", values_to = "persentase") %>%
  mutate(
    label_indikator = case_when(
      indikator == "pangsa_pangan_persen"     ~ "Pangsa Pengeluaran Pangan",
      indikator == "pct_rt_defisit_kalori"     ~ "RT Defisit Kalori (<2.100 Kkal)",
      indikator == "pct_rt_defisit_protein"    ~ "RT Defisit Protein (<57 Gr)",
      indikator == "prevalensi_fies_persen"    ~ "Prevalensi Rawan Pangan FIES",
      indikator == "cakupan_bpnt_persen"       ~ "Cakupan Bansos Sembako (BPNT)",
      TRUE ~ indikator
    )
  )

p_desa_kota <- ggplot(df_desa_kota_plot, aes(x = label_indikator, y = persentase, fill = tipe_wilayah)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.70) +
  geom_text(aes(label = sprintf("%.1f%%", persentase)), position = position_dodge(width = 0.75), vjust = -0.4, size = 3.3, fontface = "bold") +
  scale_y_continuous(limits = c(0, 65), labels = label_percent(scale = 1)) +
  scale_fill_manual(values = c("Perkotaan" = "#457B9D", "Perdesaan" = "#E63946")) +
  labs(
    title = "Kesenjangan Indikator Kerawanan Pangan: Perkotaan vs Perdesaan",
    subtitle = "Provinsi Jawa Barat (SUSENAS 2023 Terbobot WERT)",
    x = "Indikator Kerawanan & Ketahanan Pangan",
    y = "Persentase (%)",
    fill = "Wilayah",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2023"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "gray30", margin = margin(b = 10)),
    axis.text.x = element_text(angle = 15, hjust = 1, face = "bold"),
    legend.position = "top",
    panel.grid.minor = element_blank()
  )

# ------------------------------------------------------------------------------
# 7. EKSPOR BERKAS OUTPUT KE export_script_r/ & output/
# ------------------------------------------------------------------------------
message(">> [Step 7/8] Mengekspor tabel data dan visualisasi ke direktori output...")

export_folders <- c(
  file.path(ROOT_DIR, "export_script_r"),
  file.path(ROOT_DIR, "output")
)

for (f in export_folders) {
  if (!dir.exists(f)) dir.create(f, recursive = TRUE, showWarnings = FALSE)
}

# 1. Simpan CSV ke folder export_script_r
write_csv(df_kabkot, file.path(ROOT_DIR, "export_script_r", "tabel_rawan_pangan_kabkot.csv"))
write_csv(df_desa_kota, file.path(ROOT_DIR, "export_script_r", "tabel_rawan_pangan_desa_kota.csv"))

# 2. Simpan CSV ke folder output
write_csv(df_kabkot, file.path(ROOT_DIR, "output", "tabel_rawan_pangan_kabkot.csv"))
write_csv(df_desa_kota, file.path(ROOT_DIR, "output", "tabel_rawan_pangan_desa_kota.csv"))

# 3. Simpan Grafik PNG ke export_script_r dan output
ggsave(file.path(ROOT_DIR, "export_script_r", "grafik_ranking_rawan_pangan.png"), plot = p_ranking, width = 9.5, height = 7.5, dpi = 300)
ggsave(file.path(ROOT_DIR, "export_script_r", "grafik_matriks_rawan_pangan.png"), plot = p_matriks, width = 8.5, height = 6.2, dpi = 300)
ggsave(file.path(ROOT_DIR, "export_script_r", "grafik_disparitas_desa_kota.png"), plot = p_desa_kota, width = 9.0, height = 5.5, dpi = 300)

ggsave(file.path(ROOT_DIR, "output", "grafik_ranking_rawan_pangan.png"), plot = p_ranking, width = 9.5, height = 7.5, dpi = 300)
ggsave(file.path(ROOT_DIR, "output", "grafik_matriks_rawan_pangan.png"), plot = p_matriks, width = 8.5, height = 6.2, dpi = 300)
ggsave(file.path(ROOT_DIR, "output", "grafik_disparitas_desa_kota.png"), plot = p_desa_kota, width = 9.0, height = 5.5, dpi = 300)

# 4. Simpan Bundle RDS
bundle_rawan <- list(
  metadata = list(
    topik = "Identifikasi Daerah Rawan Pangan Jawa Barat 2023",
    environment = ENV_NAME,
    root_dir = ROOT_DIR,
    tanggal_komputasi = Sys.time()
  ),
  tabel_kabkot = df_kabkot,
  tabel_desa_kota = df_desa_kota,
  grafik_ranking = p_ranking,
  grafik_matriks = p_matriks,
  grafik_desa_kota = p_desa_kota
)
saveRDS(bundle_rawan, file.path(ROOT_DIR, "export_script_r", "hasil_rawan_pangan_lengkap.rds"))
saveRDS(bundle_rawan, file.path(ROOT_DIR, "output", "hasil_rawan_pangan_lengkap.rds"))

message("==============================================================================")
message(">> EKSPOR IDENTIFIKASI DAERAH RAWAN PANGAN SELESAI SUKSES!")
message(">> Berkas tersedia pada folder [export_script_r/] dan [output/]:")
message("   - tabel_rawan_pangan_kabkot.csv")
message("   - tabel_rawan_pangan_desa_kota.csv")
message("   - grafik_ranking_rawan_pangan.png")
message("   - grafik_matriks_rawan_pangan.png")
message("   - grafik_disparitas_desa_kota.png")
message("   - hasil_rawan_pangan_lengkap.rds")
message("==============================================================================")

# Tampilkan 10 Daerah Paling Rawan Pangan ke Konsol
cat("\n=== TOP 10 DAERAH DENGAN SKOR KERAWANAN PANGAN TERTINGGI (JAWA BARAT 2023) ===\n")
print(as.data.frame(df_kabkot[1:10, c("ranking_kerawanan", "status_prioritas", "nama_kabkot", "skor_kerawanan_komposit", "pangsa_pangan_persen", "pct_rt_defisit_kalori", "prevalensi_fies_skor_ge1", "cakupan_bpnt_persen")]))
cat("\n")
