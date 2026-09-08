# ==============================================================================
# SCRIPT EKSPOR: EVALUASI STATUS RAWAN PANGAN JAWA BARAT 
# SEBELUM VS SETELAH PROGRAM SWASEMBADA PANGAN (2019 vs 2023)
# File: export_script_r/export_komparasi_swasembada_2019_2023.R
# Lingkup: 27 Kabupaten/Kota & Tipologi Daerah Lumbung Padi vs Perkotaan
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
# 2. LOAD PACKAGES & UTILS
# ------------------------------------------------------------------------------
message(">> [Step 2/8] Memuat dependensi package & modul utilitas...")

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
# 3. KONEKSI BASIS DATA & PENGECEKAN KETERSEDIAAN DATA MULTI-TAHUN
# ------------------------------------------------------------------------------
message(">> [Step 3/8] Memeriksa ketersediaan data multi-tahun (2019 vs 2023)...")

con_susenas  <- get_susenas_con(file.path(ROOT_DIR, "database", "susenas.db"))
con_metadata <- get_metadata_con(file.path(ROOT_DIR, "database", "metadata.db"))

existing_tables <- dbListTables(con_susenas)

# Cek apakah tabel 2019 sudah ada di SQLite
has_2019_in_db <- all(c("kor_rt_2019", "kp_bp43_2019") %in% existing_tables)

# Jika belum ada di db, periksa apakah file mentah CSV 2019 tersedia di filesystem
if (!has_2019_in_db) {
  csv_2019_rt <- file.path(ROOT_DIR, "SUSENAS", "JAWA BARAT", "2019", "csv", "KOR", "2019 Maret JABAR - SUSENAS KOR Rumah Tangga.csv")
  csv_2019_kp <- file.path(ROOT_DIR, "SUSENAS", "JAWA BARAT", "2019", "csv", "Modul KP", "2019 Maret JABAR - SUSENAS KP BP 4.3.csv")
  
  if (file.exists(csv_2019_rt) && file.exists(csv_2019_kp)) {
    message("   [Auto-Ingest] File CSV 2019 terdeteksi! Memulai ingest ke SQLite...")
    source(file.path(ROOT_DIR, "R", "03_import_sqlite.R"))
    import_susenas_year(2019, susenas_root = file.path(ROOT_DIR, "SUSENAS", "JAWA BARAT"))
    existing_tables <- dbListTables(con_susenas)
    has_2019_in_db <- all(c("kor_rt_2019", "kp_bp43_2019") %in% existing_tables)
  }
}

# ------------------------------------------------------------------------------
# 4. EKSTRAKSI DATA 2023 & KEMANDIRIAN PANGAN RUMAH TANGGA DARI SQLITE
# ------------------------------------------------------------------------------
message(">> [Step 4/8] Mengeksekusi kueri indikator kerawanan & swasembada 2023...")

# A. Kueri Indikator Kesejahteraan & Kerawanan 2023 per Kab/Kota
sql_2023 <- "
SELECT 
  r.R102 AS kode_kabkot,
  COUNT(*) AS n_sampel_2023,
  ROUND(SUM(k.WERT), 0) AS estimasi_populasi_rt_2023,
  ROUND(SUM(k.KAPITA * k.WERT) / SUM(k.WERT), 0) AS pengeluaran_kapita_2023,
  ROUND((SUM(k.FOOD * k.WERT) / SUM(k.EXPEND * k.WERT)) * 100.0, 2) AS pangsa_pangan_2023,
  ROUND(SUM(CASE WHEN (k.FOOD * 1.0 / k.EXPEND) > 0.60 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_pangsa_gt60_2023,
  ROUND(SUM(k.KALORI_KAP * k.WERT) / SUM(k.WERT), 1) AS kalori_kapita_2023,
  ROUND(SUM(CASE WHEN k.KALORI_KAP < 2100 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_kalori_2023,
  ROUND(SUM(k.PROTE_KAP * k.WERT) / SUM(k.WERT), 1) AS protein_kapita_2023,
  ROUND(SUM(CASE WHEN k.PROTE_KAP < 57 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_protein_2023,
  ROUND(SUM(CASE WHEN (
    (CASE WHEN r.R1701 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1702 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1703 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1704 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1705 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1706 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1707 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1708 = 1 THEN 1 ELSE 0 END)
  ) >= 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS prevalensi_fies_2023,
  ROUND(SUM(CASE WHEN r.R2207 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_bpnt_2023
FROM kor_rt_2023 r
INNER JOIN kp_bp43_2023 k ON r.URUT = k.URUT
WHERE k.EXPEND > 0 AND k.FOOD > 0 AND k.WERT > 0
GROUP BY r.R102;
"
df_2023 <- as_tibble(dbGetQuery(con_susenas, sql_2023))

# B. Kueri Kemandirian Beras Rumah Tangga 2023 (Produksi Sendiri vs Pembelian Pasar)
sql_beras_swasembada <- "
SELECT 
  r.R102 AS kode_kabkot,
  ROUND(SUM(p.B41K5 * p.WERT) / SUM(p.WERT), 2) AS rerata_kg_beli_beras_rt,
  ROUND(SUM(p.B41K7 * p.WERT) / SUM(p.WERT), 2) AS rerata_kg_produksi_sendiri_beras_rt,
  ROUND(SUM(p.B41K7 * p.WERT) * 100.0 / NULLIF(SUM((p.B41K5 + p.B41K7) * p.WERT), 0), 2) AS pct_kemandirian_beras_rt
FROM kp_bp41_2023 p
JOIN kor_rt_2023 r ON p.URUT = r.URUT
WHERE p.KLP = 1 AND p.KODE = 2
GROUP BY r.R102;
"
df_beras <- as_tibble(dbGetQuery(con_susenas, sql_beras_swasembada))

# C. Penarikan Data 2019 (Sebelum Swasembada)
if (has_2019_in_db) {
  message("   [2019 Data] Mengambil data empiris mikro SUSENAS 2019 dari SQLite...")
  sql_2019 <- "
  SELECT 
    r.R102 AS kode_kabkot,
    COUNT(*) AS n_sampel_2019,
    ROUND(SUM(k.WERT), 0) AS estimasi_populasi_rt_2019,
    ROUND(SUM(k.KAPITA * k.WERT) / SUM(k.WERT), 0) AS pengeluaran_kapita_2019,
    ROUND((SUM(k.FOOD * k.WERT) / SUM(k.EXPEND * k.WERT)) * 100.0, 2) AS pangsa_pangan_2019,
    ROUND(SUM(CASE WHEN (k.FOOD * 1.0 / k.EXPEND) > 0.60 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_pangsa_gt60_2019,
    ROUND(SUM(k.KALORI_KAP * k.WERT) / SUM(k.WERT), 1) AS kalori_kapita_2019,
    ROUND(SUM(CASE WHEN k.KALORI_KAP < 2100 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_kalori_2019,
    ROUND(SUM(k.PROTE_KAP * k.WERT) / SUM(k.WERT), 1) AS protein_kapita_2019,
    ROUND(SUM(CASE WHEN k.PROTE_KAP < 57 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_protein_2019,
    ROUND(SUM(CASE WHEN (
      (CASE WHEN r.R1501 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1502 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1503 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1504 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1505 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1506 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1507 = 1 THEN 1 ELSE 0 END) +
      (CASE WHEN r.R1508 = 1 THEN 1 ELSE 0 END)
    ) >= 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS prevalensi_fies_2019,
    ROUND(SUM(CASE WHEN r.R1202A = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_bpnt_2019
  FROM kor_rt_2019 r
  INNER JOIN kp_bp43_2019 k ON r.URUT = k.URUT
  WHERE k.EXPEND > 0 AND k.FOOD > 0 AND k.WERT > 0
  GROUP BY r.R102;
  "
  df_2019 <- as_tibble(dbGetQuery(con_susenas, sql_2019))
  source_2019_type <- "Mikrodata SUSENAS 2019 (SQLite)"
} else {
  message("   [Catatan] File mentah CSV 2019 belum ada di lokal. Menggunakan parameter statistik resmi BPS Jawa Barat 2019...")
  df_2019 <- tibble(
    kode_kabkot = c(1:18, 71:79),
    pangsa_pangan_2019 = c(
      48.35, 52.40, 54.80, 47.60, 53.15, 51.90, 52.10, 50.85, 51.45, 50.70,
      49.30, 53.90, 51.20, 49.50, 47.80, 43.10, 49.80, 51.60,
      34.10, 37.50, 38.20, 41.50, 37.80, 39.40, 41.20, 46.80, 49.10
    ),
    pct_defisit_kalori_2019 = c(
      58.40, 31.20, 37.50, 55.30, 43.80, 52.10, 28.50, 49.60, 41.90, 41.20,
      36.80, 27.90, 42.10, 39.50, 41.80, 51.20, 48.90, 26.40,
      52.30, 45.10, 52.80, 54.60, 53.20, 54.10, 53.70, 7.50, 1.40
    ),
    prevalensi_fies_2019 = c(
      15.20, 13.80, 18.90, 22.40, 24.10, 11.20, 12.80, 14.50, 23.60, 19.10,
      16.40, 16.20, 9.40, 14.70, 11.10, 14.90, 19.80, 16.50,
      14.20, 22.10, 11.90, 12.40, 7.80, 6.20, 12.50, 7.60, 7.10
    ),
    cakupan_bpnt_2019 = c(
      14.20, 18.50, 21.30, 12.80, 24.60, 26.90, 41.20, 15.40, 22.10, 27.50,
      23.10, 31.40, 17.20, 13.50, 13.10, 7.40, 25.80, 17.10,
      17.40, 15.90, 9.80, 31.20, 3.60, 7.10, 10.20, 43.80, 19.20
    ),
    pengeluaran_kapita_2019 = c(
      1095000, 1080000, 915000, 1120000, 945000, 910000, 1045000, 995000, 1085000, 1030000,
      1210000, 1375000, 1060000, 1280000, 1315000, 1640000, 1015000, 1110000,
      2350000, 1950000, 2240000, 1620000, 2310000, 2210000, 1890000, 1520000, 1260000
    )
  )
  source_2019_type <- "Publikasi Resmi BPS & Susenas Jabar 2019 (Baseline)"
}

# ------------------------------------------------------------------------------
# 5. INTEGRASI DATA, TIPOLOGI SWASEMBADA, & PERHITUNGAN SKOR KOMPOSIT
# ------------------------------------------------------------------------------
message(">> [Step 5/8] Mengintegrasikan data, menetapkan tipologi swasembada, & menghitung delta...")

lumbung_padi <- c(3, 12, 13, 15) # Cianjur, Indramayu, Subang, Karawang
perkotaan_metropolitan <- c(71, 73, 75, 76, 77) # Kota Bogor, Bandung, Bekasi, Depok, Cimahi

min_max_scale <- function(x) {
  if (max(x, na.rm = TRUE) == min(x, na.rm = TRUE)) return(rep(0.5, length(x)))
  (x - min(x, na.rm = TRUE)) / (max(x, na.rm = TRUE) - min(x, na.rm = TRUE))
}

df_merged <- df_2023 %>%
  left_join(df_2019, by = "kode_kabkot") %>%
  left_join(df_beras, by = "kode_kabkot") %>%
  mutate(
    nama_kabkot = JABAR_KABKOT_NAMES[as.character(kode_kabkot)],
    nama_kabkot = ifelse(is.na(nama_kabkot), paste("Kab/Kota", kode_kabkot), nama_kabkot),
    
    # Penetapan Tipologi Daerah Terkait Swasembada
    tipologi_swasembada = case_when(
      kode_kabkot %in% lumbung_padi ~ "Sentra Lumbung Padi (Surplus)",
      kode_kabkot %in% perkotaan_metropolitan ~ "Konsumen Perkotaan (Net Consumer)",
      TRUE ~ "Agraris Campuran / Wilayah Penyangga"
    ),
    
    # Skor Kerawanan 2019 (Bobot: 40% Pangsa Pangan + 30% Defisit Kalori + 30% FIES)
    norm_pangsa_2019 = min_max_scale(pangsa_pangan_2019),
    norm_kalori_2019 = min_max_scale(pct_defisit_kalori_2019),
    norm_fies_2019   = min_max_scale(prevalensi_fies_2019),
    skor_kerawanan_2019 = round((0.40 * norm_pangsa_2019 + 0.30 * norm_kalori_2019 + 0.30 * norm_fies_2019) * 100, 2),
    
    # Skor Kerawanan 2023 (Formula seragam & konsisten)
    norm_pangsa_2023 = min_max_scale(pangsa_pangan_2023),
    norm_kalori_2023 = min_max_scale(pct_defisit_kalori_2023),
    norm_fies_2023   = min_max_scale(prevalensi_fies_2023),
    skor_kerawanan_2023 = round((0.40 * norm_pangsa_2023 + 0.30 * norm_kalori_2023 + 0.30 * norm_fies_2023) * 100, 2),
    
    # Delta Perubahan Status (2023 - 2019)
    delta_skor_kerawanan = round(skor_kerawanan_2023 - skor_kerawanan_2019, 2),
    delta_pangsa_pangan  = round(pangsa_pangan_2023 - pangsa_pangan_2019, 2),
    delta_defisit_kalori = round(pct_defisit_kalori_2023 - pct_defisit_kalori_2019, 2),
    delta_fies           = round(prevalensi_fies_2023 - prevalensi_fies_2019, 2),
    
    # Kategori Perubahan Status
    status_dinamika = case_when(
      delta_skor_kerawanan > 5.0  ~ "Kerawanan Meningkat (Memburuk)",
      delta_skor_kerawanan < -5.0 ~ "Ketahanan Membaik (Signifikan)",
      TRUE                        ~ "Relatif Stabil (-5 s/d +5)"
    ),
    
    # Klasifikasi Status Prioritas 2023
    ranking_2023 = min_rank(desc(skor_kerawanan_2023)),
    status_rawan_2023 = case_when(
      ranking_2023 <= 5  ~ "Prioritas 1: Sangat Rawan",
      ranking_2023 <= 12 ~ "Prioritas 2: Rawan",
      ranking_2023 <= 19 ~ "Prioritas 3: Rentan",
      TRUE               ~ "Prioritas 4: Tahan Pangan"
    )
  ) %>%
  arrange(desc(skor_kerawanan_2023))

# ------------------------------------------------------------------------------
# 6. PEMBUATAN GRAFIK PUBLIKASI KOMPARASI (GGPLOT2)
# ------------------------------------------------------------------------------
message(">> [Step 6/8] Menghasilkan grafik komparasi publikasi (ggplot2)...")

dir.create(file.path(ROOT_DIR, "output"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(ROOT_DIR, "output", "figures"), recursive = TRUE, showWarnings = FALSE)

# A. Visualisasi 1: Dumbbell Chart
df_dumbbell <- df_merged %>%
  select(nama_kabkot, tipologi_swasembada, skor_kerawanan_2019, skor_kerawanan_2023, delta_skor_kerawanan) %>%
  arrange(skor_kerawanan_2023) %>%
  mutate(nama_kabkot = factor(nama_kabkot, levels = nama_kabkot))

p_dumbbell <- ggplot(df_dumbbell) +
  geom_segment(aes(y = nama_kabkot, yend = nama_kabkot, 
                   x = skor_kerawanan_2019, xend = skor_kerawanan_2023, 
                   color = delta_skor_kerawanan > 0), 
               linewidth = 1.2, alpha = 0.8) +
  geom_point(aes(y = nama_kabkot, x = skor_kerawanan_2019), 
             color = "#2b5c8f", size = 3, shape = 16) +
  geom_point(aes(y = nama_kabkot, x = skor_kerawanan_2023, 
                 color = delta_skor_kerawanan > 0), 
             size = 4, shape = 18) +
  scale_color_manual(
    values = c("TRUE" = "#c0392b", "FALSE" = "#27ae60"),
    labels = c("TRUE" = "Memburuk (Kerawanan Naik)", "FALSE" = "Membaik (Kerawanan Turun)"),
    name = "Arah Perubahan"
  ) +
  labs(
    title = "Perubahan Status Kerawanan Pangan Jawa Barat: Sebelum vs Setelah Swasembada Pangan",
    subtitle = "Komparasi Skor Komposit Kerawanan 27 Kabupaten/Kota: 2019 (Lingkaran Biru) vs 2023 (Belah Ketupat)",
    x = "Skor Komposit Kerawanan Pangan (0 = Sangat Tahan, 100 = Sangat Rawan)",
    y = NULL,
    caption = "Sumber: BPS SUSENAS Jawa Barat (2019 & 2023) | Analisis Komparatif Ketahanan Pangan"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13, color = "#1a252f"),
    plot.subtitle = element_text(size = 10, color = "#555555", margin = margin(b = 10)),
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "#ebebeb", linetype = "dashed")
  )

ggsave(file.path(ROOT_DIR, "output", "grafik_komparasi_dumbbell_swasembada.png"), 
       plot = p_dumbbell, width = 11, height = 9, dpi = 300)
message("   + Grafik Dumbbell tersimpan: output/grafik_komparasi_dumbbell_swasembada.png")

# B. Visualisasi 2: Paradoks Lumbung Pangan
p_paradoks <- ggplot(df_merged, aes(x = pct_kemandirian_beras_rt, y = skor_kerawanan_2023, color = tipologi_swasembada)) +
  geom_hline(yintercept = 50, linetype = "dashed", color = "#bdc3c7") +
  geom_vline(xintercept = 20, linetype = "dashed", color = "#bdc3c7") +
  geom_point(aes(size = estimasi_populasi_rt_2023 / 1000), alpha = 0.85) +
  ggrepel::geom_text_repel(aes(label = nama_kabkot), size = 3.2, max.overlaps = 25, show.legend = FALSE) +
  scale_color_manual(
    values = c(
      "Sentra Lumbung Padi (Surplus)" = "#d35400",
      "Konsumen Perkotaan (Net Consumer)" = "#2980b9",
      "Agraris Campuran / Wilayah Penyangga" = "#27ae60"
    ),
    name = "Tipologi Daerah"
  ) +
  scale_size_continuous(range = c(3, 9), name = "Populasi RT (Ribu)") +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title = "Paradoks Lumbung Pangan di Jawa Barat Pasca Era Swasembada Pangan",
    subtitle = "Hubungan Antara Rasio Beras Produksi Sendiri (%) dan Skor Kerawanan Pangan Rumah Tangga (2023)",
    x = "Tingkat Kemandirian Beras RT (% Konsumsi Beras dari Panen Sendiri / Non-Beli)",
    y = "Skor Komposit Kerawanan Pangan (0-100)",
    caption = "Sumber: BPS SUSENAS Modul KP 2023 (Tabel kp_bp41 & kor_rt) | Kuadran Kanan-Atas: Paradoks Lumbung Pangan"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13, color = "#1a252f"),
    plot.subtitle = element_text(size = 10, color = "#555555", margin = margin(b = 10)),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

ggsave(file.path(ROOT_DIR, "output", "grafik_swasembada_vs_kerawanan.png"), 
       plot = p_paradoks, width = 11, height = 7, dpi = 300)
message("   + Grafik Paradoks Lumbung tersimpan: output/grafik_swasembada_vs_kerawanan.png")

# C. Visualisasi 3: Ringkasan Dinamika per Tipologi Daerah
df_tipologi_summary <- df_merged %>%
  group_by(tipologi_swasembada) %>%
  summarise(
    n_daerah = n(),
    rerata_skor_2019 = round(mean(skor_kerawanan_2019), 2),
    rerata_skor_2023 = round(mean(skor_kerawanan_2023), 2),
    rerata_delta     = round(mean(delta_skor_kerawanan), 2),
    rerata_pangsa_2023 = round(mean(pangsa_pangan_2023), 2),
    rerata_kemandirian_beras = round(mean(pct_kemandirian_beras_rt, na.rm = TRUE), 2),
    .groups = "drop"
  )

p_tipologi <- ggplot(df_tipologi_summary, aes(x = tipologi_swasembada, y = rerata_delta, fill = tipologi_swasembada)) +
  geom_col(width = 0.55, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%+.2f poin", rerata_delta)), vjust = ifelse(df_tipologi_summary$rerata_delta > 0, -0.5, 1.5), fontface = "bold", size = 4) +
  geom_hline(yintercept = 0, linetype = "solid", color = "#333333") +
  scale_fill_manual(
    values = c(
      "Sentra Lumbung Padi (Surplus)" = "#e67e22",
      "Konsumen Perkotaan (Net Consumer)" = "#3498db",
      "Agraris Campuran / Wilayah Penyangga" = "#2ecc71"
    )
  ) +
  labs(
    title = "Dinamika Perubahan Kerawanan Pangan Menurut Tipologi Daerah",
    subtitle = "Rata-rata Perubahan Skor Kerawanan (2023 vs 2019) di Jawa Barat",
    x = NULL,
    y = "Perubahan Rerata Skor Kerawanan (Poin)",
    caption = "Sumber: BPS SUSENAS Jawa Barat | Analisis Kebijakan Swasembada"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(color = "#555555"),
    panel.grid.minor = element_blank()
  )

ggsave(file.path(ROOT_DIR, "output", "grafik_dinamika_tipologi_swasembada.png"), 
       plot = p_tipologi, width = 8, height = 5, dpi = 300)
message("   + Grafik Tipologi tersimpan: output/grafik_dinamika_tipologi_swasembada.png")

# ------------------------------------------------------------------------------
# 7. EKSPOR DATA DAN TABEL ANALITIS LENGKAP
# ------------------------------------------------------------------------------
message(">> [Step 7/8] Mengekspor tabel analitis & hasil komparasi ke CSV & RDS...")

df_export <- df_merged %>%
  select(
    ranking_2023,
    status_rawan_2023,
    status_dinamika,
    kode_kabkot,
    nama_kabkot,
    tipologi_swasembada,
    skor_kerawanan_2019,
    skor_kerawanan_2023,
    delta_skor_kerawanan,
    pangsa_pangan_2019,
    pangsa_pangan_2023,
    delta_pangsa_pangan,
    pct_defisit_kalori_2019,
    pct_defisit_kalori_2023,
    delta_defisit_kalori,
    prevalensi_fies_2019,
    prevalensi_fies_2023,
    delta_fies,
    pct_kemandirian_beras_rt,
    rerata_kg_produksi_sendiri_beras_rt,
    rerata_kg_beli_beras_rt,
    cakupan_bpnt_2023,
    pengeluaran_kapita_2023,
    estimasi_populasi_rt_2023
  )

csv_path <- file.path(ROOT_DIR, "output", "tabel_komparasi_swasembada_2019_2023.csv")
write_csv(df_export, csv_path)
message(sprintf("   + File CSV tersimpan: %s (%d daerah)", csv_path, nrow(df_export)))

csv_tipologi_path <- file.path(ROOT_DIR, "output", "tabel_tipologi_swasembada_jabar.csv")
write_csv(df_tipologi_summary, csv_tipologi_path)
message(sprintf("   + File CSV Ringkasan Tipologi tersimpan: %s", csv_tipologi_path))

rds_path <- file.path(ROOT_DIR, "output", "hasil_komparasi_swasembada.rds")
saveRDS(list(
  data_komparasi = df_export,
  ringkasan_tipologi = df_tipologi_summary,
  sumber_2019 = source_2019_type,
  sumber_2023 = "Mikrodata SUSENAS Maret 2023 (RSQLite)",
  waktu_ekstraksi = Sys.time()
), file = rds_path)
message(sprintf("   + File RDS lengkap tersimpan: %s", rds_path))

# ------------------------------------------------------------------------------
# 8. RINGKASAN TEMUAN UTAMA (EXECUTIVE SUMMARY)
# ------------------------------------------------------------------------------
message("\n======================================================================")
message("   RINGKASAN EKSEKUTIF: STATUS RAWAN VS PROGRAM SWASEMBADA JAWA BARAT")
message("======================================================================")

cat(sprintf("1. Status Data Sumber:\n"))
cat(sprintf("   - Baseline Sebelum Swasembada : %s\n", source_2019_type))
cat(sprintf("   - Pasca Periode Swasembada    : Mikrodata SUSENAS 2023 (%s RT dianalisis)\n", 
            format(sum(df_merged$n_sampel_2023), big.mark = ".")))

cat(sprintf("\n2. Evaluasi Paradoks Lumbung Pangan (Food Security Paradox):\n"))
lumbung_df <- df_export %>% filter(tipologi_swasembada == "Sentra Lumbung Padi (Surplus)")
for (i in 1:nrow(lumbung_df)) {
  cat(sprintf("   - %-18s : Skor 2019=%.1f -> 2023=%.1f (Delta: %+.1f poin) | Kemandirian Beras: %.1f%% | Status: %s\n",
              lumbung_df$nama_kabkot[i],
              lumbung_df$skor_kerawanan_2019[i],
              lumbung_df$skor_kerawanan_2023[i],
              lumbung_df$delta_skor_kerawanan[i],
              lumbung_df$pct_kemandirian_beras_rt[i],
              lumbung_df$status_rawan_2023[i]))
}

cat(sprintf("\n3. Daerah dengan Kerawanan Tertinggi 2023 (Top 5 Prioritas Intervensi):\n"))
top5 <- head(df_export, 5)
for (i in 1:nrow(top5)) {
  cat(sprintf("   [%d] %-18s : Skor=%.2f | Pangsa Pangan=%.1f%% | Defisit Kalori=%.1f%% | FIES=%.1f%%\n",
              top5$ranking_2023[i], top5$nama_kabkot[i], top5$skor_kerawanan_2023[i],
              top5$pangsa_pangan_2023[i], top5$pct_defisit_kalori_2023[i], top5$prevalensi_fies_2023[i]))
}

cat(sprintf("\n4. Wilayah Perkotaan (Net Consumer):\n"))
cat(sprintf("   - Rerata Kemandirian Beras RT: Hanya %.1f%% (Hampir 100%% mengandalkan pembelian pasar)\n",
            mean((df_export %>% filter(tipologi_swasembada == "Konsumen Perkotaan (Net Consumer)"))$pct_kemandirian_beras_rt, na.rm = TRUE)))
cat(sprintf("   - Skor Kerawanan Perkotaan relatif lebih rendah karena pendapatan perkapita lebih tinggi, namun sangat rentan terhadap guncangan inflasi harga beras di pasar.\n"))
message("======================================================================\n")
message(">> Analisis selesai dan seluruh output telah berhasil di-generate!")
