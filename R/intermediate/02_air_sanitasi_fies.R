# ==============================================================================
# PENELITIAN 2: Akses Air Minum, Sanitasi Layak (WASH), dan FIES (2019-2023)
# Paket yang Digunakan: Hanya Bawaan R (Base R) + dplyr + ggplot2
# Dilengkapi: Label Resmi Asli Kuesioner SUSENAS (VSEN.K BPS)
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data & Menghubungkan Variabel dengan Label Asli Kuesioner
# ------------------------------------------------------------------------------
ambil_data_wash <- function(tahun) {
  cat("\nMemproses Tahun:", tahun, "\n")
  
  root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
    file.path("SUSENAS", "JAWA BARAT")
  } else {
    "JAWA BARAT"
  }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  
  # Standarisasi Kolom ID Rumah Tangga (2019-2021: RENUM, 2022-2023: URUT)
  if (tahun <= 2021) {
    data_rt$id_rt <- data_rt$RENUM
  } else {
    data_rt$id_rt <- data_rt$URUT
  }
  
  # ----------------------------------------------------------------------------
  # DAFTAR VARIABEL & LABEL ASLI DARI KUESIONER SUSENAS (VSEN.K):
  #
  # [BLOK I. KETERANGAN TEMPAT]
  # - R101   : Provinsi
  # - R102   : Kabupaten/Kota
  # - R105   : Klasifikasi Desa/Kelurahan (1 = Perkotaan, 2 = Perdesaan)
  #
  # [BLOK III. RINGKASAN]
  # - R301   : Banyaknya anggota rumah tangga (ART)
  #
  # [FAKTOR PENIMBANG BPS]
  # - FWT    : Faktor Penimbang Akhir (Final Weight / Bobot Populasi BPS)
  #
  # [BLOK XVIII. KETERANGAN PERUMAHAN (WASH / WATER, SANITATION & HYGIENE)]
  # - R1810A : Apa sumber air utama yang digunakan rumah tangga untuk minum?
  #            Pilihan: 1. Air kemasan bermerek, 2. Air isi ulang, 3. Leding, 
  #                     4. Sumur bor/pompa, 5. Sumur terlindung, 6. Sumur tak terlindung, 
  #                     7. Mata air terlindung, 8. Mata air tak terlindung, 
  #                     9. Air permukaan, 10. Air hujan, 11. Lainnya
  #
  # - R1809A : Apakah memiliki fasilitas tempat buang air besar dan siapa saja yang menggunakan?
  #            Pilihan: 1. Ada, digunakan hanya ART sendiri
  #                     2. Ada, digunakan bersama ART rumah tangga tertentu
  #                     3. Ada, di MCK komunal
  #                     4. Ada, di MCK umum/siapapun menggunakan
  #                     5. Ada, ART tidak menggunakan
  #                     6. Tidak ada fasilitas
  #
  # - R1809B : Apakah jenis kloset yang digunakan?
  #            Pilihan: 1. Leher angsa, 2. Plengsengan dengan tutup, 
  #                     3. Plengsengan tanpa tutup, 4. Cemplung/cubluk
  #
  # - R1809C : Di manakah tempat pembuangan akhir tinja?
  #            Pilihan: 1. Tangki septik, 2. IPAL, 3. Kolam/sawah/sungai/danau/laut, 
  #                     4. Lubang tanah, 5. Pantai/tanah lapang/kebun, 6. Lainnya
  #
  # [BLOK XVII. AKSES TERHADAP MAKANAN (FIES)]
  # - R1701  : Khawatir tidak memiliki cukup makanan
  # - R1702  : Tidak dapat menyantap makanan sehat dan bergizi
  # - R1703  : Hanya menyantap sedikit jenis makanan
  # - R1704  : Melewatkan satu waktu makan karena ketiadaan uang/sumber daya
  # - R1705  : Makan lebih sedikit daripada seharusnya
  # - R1706  : Rumah tangga kehabisan makanan
  # - R1707  : Merasa lapar tapi tidak makan
  # - R1708  : Tidak makan seharian karena ketiadaan uang/sumber daya
  # ----------------------------------------------------------------------------
  kolom_rt <- c("id_rt", "R101", "R102", "R105", "R301", "FWT",
                "R1810A", "R1809A", "R1809B", "R1809C",
                "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  data_rt <- data_rt[, kolom_rt]
  
  # ----------------------------------------------------------------------------
  # DEFINISI INDIKATOR KELAYAKAN WASH (STANDAR BPS & SDGS):
  # ----------------------------------------------------------------------------
  hasil <- data_rt %>%
    mutate(
      tahun = tahun,
      # Skor FIES (0 sampai 8)
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan Pangan", "Tahan Pangan"),
      
      # Air Minum Layak: Leding, Pompa/Bor, Sumur Terlindung, Mata Air Terlindung, Air Hujan
      air_layak = ifelse(R1810A %in% c(1, 2, 3, 4, 6, 7), "Air Layak", "Air Tidak Layak"),
      
      # Sanitasi Layak: Fasilitas sendiri/bersama (1,2) + Kloset leher angsa (1) + Tangki septik/IPAL (1)
      sanitasi_layak = ifelse(R1809A %in% c(1, 2) & R1809B == 1 & R1809C == 1, 
                              "Sanitasi Layak", "Sanitasi Tidak Layak"),
      
      # Kombinasi Fasilitas untuk Analisis Interaksi
      kombinasi_wash = case_when(
        air_layak == "Air Layak" & sanitasi_layak == "Sanitasi Layak" ~ "Air & Sanitasi Layak",
        air_layak == "Air Layak" & sanitasi_layak != "Sanitasi Layak" ~ "Hanya Air Layak",
        air_layak != "Air Layak" & sanitasi_layak == "Sanitasi Layak" ~ "Hanya Sanitasi Layak",
        TRUE ~ "Keduanya Tidak Layak"
      )
    )
  
  return(hasil)
}

# ------------------------------------------------------------------------------
# 2. Mengumpulkan Data 5 Tahun (2019-2023)
# ------------------------------------------------------------------------------
daftar_tahun <- 2019:2023
list_wash <- list()

for (th in daftar_tahun) {
  list_wash[[as.character(th)]] <- ambil_data_wash(th)
}

df_wash_fies <- bind_rows(list_wash)
cat("\nTotal Data Rumah Tangga Tergabung (2019-2023):", nrow(df_wash_fies), "baris\n")

# ------------------------------------------------------------------------------
# 3. Analisis Statistik Klasik
# ------------------------------------------------------------------------------

# A. Tabel Kontingensi & Uji Chi-Square (Sanitasi vs Kerawanan Pangan)
cat("\n=== TABEL KONTINGENSI & CHI-SQUARE: SANITASI VS RAWAN PANGAN ===\n")
tab_sanitasi <- table(df_wash_fies$sanitasi_layak, df_wash_fies$status_rawan)
print(tab_sanitasi)
print(round(prop.table(tab_sanitasi, 1) * 100, 2))
print(chisq.test(tab_sanitasi))

# B. Tabel Kontingensi & Uji Chi-Square (Air Minum vs Kerawanan Pangan)
cat("\n=== TABEL KONTINGENSI & CHI-SQUARE: AIR MINUM VS RAWAN PANGAN ===\n")
tab_air <- table(df_wash_fies$air_layak, df_wash_fies$status_rawan)
print(tab_air)
print(chisq.test(tab_air))

# C. Uji-t Beda Rata-rata Skor FIES Menurut Kelayakan Sanitasi
cat("\n=== UJI-T BEDA SKOR FIES (SANITASI LAYAK VS TIDAK) ===\n")
print(t.test(skor_fies ~ sanitasi_layak, data = df_wash_fies))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis (ggplot2)
# ------------------------------------------------------------------------------
df_plot_wash <- df_wash_fies %>%
  group_by(tahun, kombinasi_wash) %>%
  summarise(rata_fies = mean(skor_fies), .groups = "drop")

p2 <- ggplot(df_plot_wash, aes(x = factor(tahun), y = rata_fies, color = kombinasi_wash, group = kombinasi_wash)) +
  geom_line(linewidth = 1.2) + 
  geom_point(size = 3) +
  scale_color_brewer(palette = "Set1") +
  labs(
    title = "Kesenjangan Kerawanan Pangan Menurut Kelayakan Fasilitas WASH",
    subtitle = "Tren Rata-rata Skor FIES Berdasarkan Akses Air Minum & Sanitasi Layak (2019–2023)",
    x = "Tahun Survei", 
    y = "Rata-rata Skor FIES (0 - 8)", 
    color = "Fasilitas WASH",
    caption = "Sumber: Olahan Mikrodata SUSENAS KOR Jawa Barat 2019-2023 (BPS)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "bottom"
  )

print(p2)
