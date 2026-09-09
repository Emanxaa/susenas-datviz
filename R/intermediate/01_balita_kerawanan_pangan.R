# ==============================================================================
# PENELITIAN 1: Balita dan Kerawanan Pangan (SUSENAS 2019-2023)
# Paket yang Digunakan: Hanya Bawaan R (Base R) + dplyr + ggplot2
# Dilengkapi: Label Resmi Asli Kuesioner SUSENAS (VSEN.K BPS)
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data & Menghubungkan Variabel dengan Label Asli Kuesioner
# ------------------------------------------------------------------------------
ambil_data_balita <- function(tahun) {
  cat("\nMemproses Tahun:", tahun, "\n")
  
  # Deteksi root folder data otomatis
  root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
    file.path("SUSENAS", "JAWA BARAT")
  } else {
    "JAWA BARAT"
  }
  
  file_rt <- file.path(
    root_data, tahun, "csv", "KOR",
    paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv")
  )
  file_ind <- file.path(
    root_data, tahun, "csv", "KOR",
    paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
  )
  
  # Membaca data dengan read.csv
  data_rt  <- read.csv(file_rt, stringsAsFactors = FALSE)
  data_ind <- read.csv(file_ind, stringsAsFactors = FALSE)
  
  # ----------------------------------------------------------------------------
  # STANDARISASI KUNCI IDENTITAS RUMAH TANGGA:
  # 2019-2021: RENUM (Nomor Urut Pengenalan Rumah Tangga)
  # 2022-2023: URUT  (Nomor Urut Sampel Rumah Tangga)
  # ----------------------------------------------------------------------------
  if (tahun <= 2021) {
    data_rt$id_rt  <- data_rt$RENUM
    data_ind$id_rt <- data_ind$RENUM
  } else {
    data_rt$id_rt  <- data_rt$URUT
    data_ind$id_rt <- data_ind$URUT
  }
  
  # ----------------------------------------------------------------------------
  # DAFTAR VARIABEL & LABEL ASLI DARI KUESIONER SUSENAS (VSEN.K):
  #
  # [BLOK I. KETERANGAN TEMPAT]
  # - R101  : Provinsi (32 = Jawa Barat)
  # - R102  : Kabupaten/Kota (01-18 = Kabupaten, 71-79 = Kota)
  # - R105  : Klasifikasi Desa/Kelurahan (1 = Perkotaan, 2 = Perdesaan)
  #
  # [BLOK III. RINGKASAN]
  # - R301  : Banyaknya anggota rumah tangga (ART)
  #
  # [FAKTOR PENIMBANG BPS]
  # - FWT   : Faktor Penimbang Akhir (Final Weight / Bobot Representasi Populasi BPS)
  #
  # [BLOK XVII. AKSES TERHADAP MAKANAN (FIES / FOOD INSECURITY EXPERIENCE SCALE)]
  # Pertanyaan diajukan dengan pengantar: "Dalam setahun terakhir, apakah ada saat di mana:"
  # - R1701 : Selama setahun terakhir, apakah Anda/ART lainnya KHAWATIR TIDAK AKAN MEMILIKI 
  #           CUKUP MAKANAN untuk disantap karena kurangnya uang atau sumber daya lainnya?
  # - R1702 : Selama setahun terakhir, apakah ada saat di mana Anda/ART lainnya TIDAK DAPAT 
  #           MENYANTAP MAKANAN SEHAT DAN BERGIZI karena kurangnya uang atau sumber daya lainnya?
  # - R1703 : Selama setahun terakhir, apakah Anda/ART lainnya HANYA MENYANTAP SEDIKIT JENIS 
  #           MAKANAN karena tidak memiliki uang atau sumber daya lainnya?
  # - R1704 : Selama setahun terakhir, apakah Anda/ART lainnya pernah MELEWATKAN SATU WAKTU 
  #           MAKAN PADA SUATU HARI TERTENTU karena tidak memiliki uang atau sumber daya lain yang cukup?
  # - R1705 : Selama setahun terakhir, apakah Anda/ART lainnya MAKAN LEBIH SEDIKIT DARIPADA 
  #           SEHARUSNYA karena kurangnya uang atau sumber daya lainnya?
  # - R1706 : Selama setahun terakhir, apakah rumah tangga KEHABISAN MAKANAN karena kurangnya 
  #           uang atau sumber daya lainnya?
  # - R1707 : Selama setahun terakhir, apakah Anda/ART lainnya MERASA LAPAR TAPI TIDAK MAKAN 
  #           karena kurangnya uang atau sumber daya lainnya untuk mendapatkan makanan?
  # - R1708 : Selama setahun terakhir, apakah Anda/ART lainnya TIDAK MAKAN SEHARIAN karena 
  #           kurangnya uang atau sumber daya lainnya?
  # ----------------------------------------------------------------------------
  kolom_rt <- c("id_rt", "R101", "R102", "R105", "R301", "FWT",
                "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  data_rt <- data_rt[, kolom_rt]
  
  # ----------------------------------------------------------------------------
  # [BLOK IV. KETERANGAN DEMOGRAFI (INDIVIDU)]
  # - R407  : Berapakah umur (nama)? (Diisi dalam tahun)
  #           Kriteria Balita: Umur < 5 tahun (0, 1, 2, 3, 4 tahun)
  # ----------------------------------------------------------------------------
  balita_rt <- data_ind %>%
    mutate(is_balita = ifelse(R407 < 5, 1, 0)) %>%
    group_by(id_rt) %>%
    summarise(jumlah_balita = sum(is_balita, na.rm = TRUE))
  
  # Gabungkan Rumah Tangga dengan Data Balita
  hasil <- data_rt %>%
    left_join(balita_rt, by = "id_rt")
  
  hasil$jumlah_balita[is.na(hasil$jumlah_balita)] <- 0
  
  # ----------------------------------------------------------------------------
  # PERHITUNGAN INDIKATOR PENELITIAN:
  # Skor FIES: Penjumlahan 8 pertanyaan (Jawaban 1 = Ya, kode lainnya = Tidak)
  # ----------------------------------------------------------------------------
  hasil <- hasil %>%
    mutate(
      tahun = tahun,
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan Pangan", "Tahan Pangan"),
      kategori_balita = case_when(
        jumlah_balita == 0 ~ "0 Balita",
        jumlah_balita == 1 ~ "1 Balita",
        jumlah_balita == 2 ~ "2 Balita",
        TRUE ~ "3+ Balita"
      )
    )
  
  return(hasil)
}

# ------------------------------------------------------------------------------
# 2. Mengumpulkan Data 5 Tahun (2019-2023)
# ------------------------------------------------------------------------------
daftar_tahun <- 2019:2023
list_data <- list()

for (th in daftar_tahun) {
  list_data[[as.character(th)]] <- ambil_data_balita(th)
}

df_balita_fies <- bind_rows(list_data)
cat("\nTotal Data Rumah Tangga Tergabung (2019-2023):", nrow(df_balita_fies), "baris\n")

# ------------------------------------------------------------------------------
# 3. Analisis Statistik Klasik
# ------------------------------------------------------------------------------

# A. Rata-rata Skor FIES Menurut Kategori Balita
cat("\n=== RATA-RATA SKOR FIES MENURUT KEBERADAAN BALITA ===\n")
print(
  df_balita_fies %>%
    group_by(kategori_balita) %>%
    summarise(
      n_sampel = n(),
      rata_skor_fies = round(mean(skor_fies, na.rm = TRUE), 3),
      rata_terbobot_fwt = round(weighted.mean(skor_fies, w = FWT, na.rm = TRUE), 3)
    )
)

# B. Uji Korelasi Pearson (Jumlah Balita vs Skor FIES)
cat("\n=== UJI KORELASI PEARSON ===\n")
print(cor.test(df_balita_fies$jumlah_balita, df_balita_fies$skor_fies))

# C. Model Regresi Linear Berganda (OLS)
cat("\n=== REGRESI LINEAR (OLS) ===\n")
model1 <- lm(skor_fies ~ jumlah_balita + factor(R105) + factor(tahun), data = df_balita_fies)
print(summary(model1))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis (ggplot2)
# ------------------------------------------------------------------------------
df_plot <- df_balita_fies %>%
  group_by(tahun, kategori_balita) %>%
  summarise(rata_fies = mean(skor_fies, na.rm = TRUE), .groups = "drop")

p1 <- ggplot(df_plot, aes(x = factor(tahun), y = rata_fies, fill = kategori_balita)) +
  geom_bar(stat = "identity", position = position_dodge(0.8), width = 0.7) +
  scale_fill_brewer(palette = "Blues") +
  labs(
    title = "Hubungan Keberadaan Balita dengan Tingkat Kerawanan Pangan",
    subtitle = "Rata-rata Skor FIES (Food Insecurity Experience Scale) di Jawa Barat (2019–2023)",
    x = "Tahun Survei",
    y = "Rata-rata Skor FIES (0 - 8)",
    fill = "Keberadaan Balita",
    caption = "Sumber: Olahan Mikrodata SUSENAS KOR Jawa Barat 2019-2023 (BPS)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "bottom"
  )

print(p1)
