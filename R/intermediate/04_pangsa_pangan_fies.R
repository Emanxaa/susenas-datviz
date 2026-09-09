# ==============================================================================
# PENELITIAN 4: Pangsa Pengeluaran Pangan (Hukum Engel) vs FIES (2019-2023)
# Paket yang Digunakan: Hanya Bawaan R (Base R) + dplyr + ggplot2
# Dilengkapi: Label Resmi Asli Kuesioner SUSENAS (VSEN.K & VSEN.KP BPS)
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data & Menghubungkan Variabel dengan Label Asli Kuesioner
# ------------------------------------------------------------------------------
ambil_data_pangsa <- function(tahun) {
  cat("\nMemproses Tahun:", tahun, "\n")
  
  root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
    file.path("SUSENAS", "JAWA BARAT")
  } else {
    "JAWA BARAT"
  }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  file_kp <- file.path(root_data, tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", 
                       paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  data_kp <- read.csv(file_kp, stringsAsFactors = FALSE)
  
  # Standarisasi Kolom ID Rumah Tangga (2019-2021: RENUM, 2022-2023: URUT)
  if (tahun <= 2021) {
    data_rt$id_rt <- data_rt$RENUM
    data_kp$id_rt <- data_kp$RENUM
  } else {
    data_rt$id_rt <- data_rt$URUT
    data_kp$id_rt <- data_kp$URUT
  }
  
  # ----------------------------------------------------------------------------
  # DAFTAR VARIABEL & LABEL ASLI DARI KUESIONER SUSENAS (VSEN.K & VSEN.KP):
  #
  # [KOR RT - BLOK I, III, & PENIMBANG]
  # - R101   : Provinsi (32 = Jawa Barat)
  # - R102   : Kabupaten/Kota
  # - R105   : Klasifikasi Desa/Kelurahan (1 = Perkotaan, 2 = Perdesaan)
  # - R301   : Banyaknya anggota rumah tangga (ART)
  # - FWT    : Faktor Penimbang Akhir (Final Weight / Bobot Representasi Populasi)
  #
  # [KOR RT - BLOK XVII. AKSES TERHADAP MAKANAN (FIES)]
  # - R1701  : Khawatir tidak memiliki cukup makanan
  # - R1702  : Tidak dapat menyantap makanan sehat dan bergizi
  # - R1703  : Hanya menyantap sedikit jenis makanan
  # - R1704  : Melewatkan satu waktu makan pada hari tertentu
  # - R1705  : Makan lebih sedikit daripada seharusnya
  # - R1706  : Rumah tangga kehabisan makanan
  # - R1707  : Merasa lapar tapi tidak makan
  # - R1708  : Tidak makan seharian karena kekurangan uang/sumber daya
  #
  # [MODUL KP BP 4.3 - REKAPITULASI KONSUMSI DAN PENGELUARAN]
  # - FOOD   : Total Nilai Pengeluaran/Konsumsi Makanan Rumah Tangga Sebulan (Rupiah)
  # - NONFOOD: Total Nilai Pengeluaran/Konsumsi Bukan Makanan Rumah Tangga Sebulan (Rupiah)
  # - EXPEND : Total Pengeluaran Konsumsi Rumah Tangga Sebulan (FOOD + NONFOOD) (Rupiah)
  # - KAPITA : Rata-rata Pengeluaran Konsumsi Per Kapita Sebulan (EXPEND / ART) (Rupiah)
  # ----------------------------------------------------------------------------
  data_rt <- data_rt[, c("id_rt", "R101", "R102", "R105", "R301", "FWT", paste0("R170", 1:8))]
  data_kp <- data_kp[, c("id_rt", "FOOD", "NONFOOD", "EXPEND", "KAPITA")]
  
  # Penggabungan Tabel KOR RT dan Modul KP
  hasil <- data_rt %>%
    left_join(data_kp, by = "id_rt") %>%
    mutate(
      tahun = tahun,
      # Skor FIES (0 sampai 8)
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan Pangan", "Tahan Pangan"),
      
      # Pangsa Pengeluaran Pangan (PPP) dalam Persen (%)
      pangsa_pangan = (FOOD / EXPEND) * 100,
      
      # Ambang Batas Klasik Hukum Engel (BPS & FAO: Ambang 60%)
      kelompok_engel = ifelse(pangsa_pangan >= 60, 
                              "PPP >= 60% (Rentan/Rawan)", 
                              "PPP < 60% (Tahan Pangan)")
    ) %>%
    # Filter integritas data
    filter(EXPEND > 0, !is.na(pangsa_pangan), pangsa_pangan <= 100)
  
  return(hasil)
}

# ------------------------------------------------------------------------------
# 2. Mengumpulkan Data 5 Tahun (2019-2023)
# ------------------------------------------------------------------------------
daftar_tahun <- 2019:2023
list_pangsa <- list()

for (th in daftar_tahun) {
  list_pangsa[[as.character(th)]] <- ambil_data_pangsa(th)
}

df_pangsa_fies <- bind_rows(list_pangsa)
cat("\nTotal Data Rumah Tangga Tergabung (2019-2023):", nrow(df_pangsa_fies), "baris\n")

# ------------------------------------------------------------------------------
# 3. Analisis Statistik Klasik
# ------------------------------------------------------------------------------

# A. Uji Korelasi Pearson (Pangsa Pengeluaran Pangan vs Skor FIES)
cat("\n=== UJI KORELASI PEARSON: PANGSA PANGAN VS SKOR FIES ===\n")
print(cor.test(df_pangsa_fies$pangsa_pangan, df_pangsa_fies$skor_fies))

# B. Uji-t Beda Rata-rata Skor FIES Menurut Kelompok Engel (PPP >= 60% vs < 60%)
cat("\n=== UJI-T BEDA RATA-RATA SKOR FIES (KELOMPOK ENGEL) ===\n")
print(t.test(skor_fies ~ kelompok_engel, data = df_pangsa_fies))

# C. Model Regresi Linear Berganda OLS
cat("\n=== REGRESI LINEAR OLS (MENGONTROL LOG KAPITA & REGIONAL) ===\n")
model4 <- lm(skor_fies ~ pangsa_pangan + log(KAPITA) + factor(R105) + factor(tahun), data = df_pangsa_fies)
print(summary(model4))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis (ggplot2)
# ------------------------------------------------------------------------------
df_plot_engel <- df_pangsa_fies %>%
  group_by(tahun, kelompok_engel) %>%
  summarise(rata_fies = mean(skor_fies), .groups = "drop")

p4 <- ggplot(df_plot_engel, aes(x = factor(tahun), y = rata_fies, fill = kelompok_engel)) +
  geom_bar(stat = "identity", position = position_dodge(0.8), width = 0.7) +
  scale_fill_manual(values = c("PPP < 60% (Tahan Pangan)" = "#27ae60", 
                               "PPP >= 60% (Rentan/Rawan)" = "#d35400")) +
  labs(
    title = "Validasi Hukum Engel: Pangsa Pangan vs Kerawanan Pangan FIES",
    subtitle = "Rumah Tangga dengan Pangsa Pangan >= 60% Memiliki Skor FIES Signifikan Lebih Tinggi",
    x = "Tahun Survei", 
    y = "Rata-rata Skor FIES (0 - 8)", 
    fill = "Kategori Engel",
    caption = "Sumber: Olahan Mikrodata SUSENAS Jawa Barat 2019-2023 (BPS)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "bottom"
  )

print(p4)
