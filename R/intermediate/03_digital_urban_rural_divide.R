# ==============================================================================
# PENELITIAN 3: Kesenjangan Internet Kota vs Desa (2020 vs 2022)
# Meneliti Apakah Jurang Digital Menyempit Setelah 2 Tahun Pandemi
# Paket: Hanya Bawaan R (Base R) + dplyr + ggplot2
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data Wilayah (Perkotaan / Perdesaan)
# ------------------------------------------------------------------------------
baca_data_wilayah <- function(tahun) {
  cat("Membaca Data Wilayah Tahun:", tahun, "...\n")
  
  root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
    file.path("SUSENAS", "JAWA BARAT")
  } else {
    "JAWA BARAT"
  }
  
  file_ind <- file.path(
    root_data, tahun, "csv", "KOR",
    paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
  )
  
  data_ind <- read.csv(file_ind, stringsAsFactors = FALSE)
  
  # ----------------------------------------------------------------------------
  # METADATA & LABEL RESMI KUESIONER BPS (VSEN.K):
  # - R105 : Klasifikasi Desa/Kelurahan (1 = Perkotaan, 2 = Perdesaan)
  # - R407 : Umur dalam tahun (Blok IV)
  # - R808 : Mengakses internet dalam 3 bulan terakhir (1 = Ya, 5 = Tidak)
  # - FWT  : Faktor Penimbang Akhir
  # ----------------------------------------------------------------------------
  
  df_filtered <- data_ind %>%
    filter(R407 >= 5) %>%
    mutate(
      tahun = tahun,
      tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan"),
      pakai_internet = ifelse(R808 == 1, 1, 0)
    ) %>%
    select(tahun, tipe_daerah, pakai_internet, FWT)
  
  return(df_filtered)
}

# ------------------------------------------------------------------------------
# 2. Gabungkan Data Dua Tahun Kunci: 2020 dan 2022
# ------------------------------------------------------------------------------
data_2020 <- baca_data_wilayah(2020)
data_2022 <- baca_data_wilayah(2022)
df_komparasi_wilayah <- bind_rows(data_2020, data_2022)

# ------------------------------------------------------------------------------
# 3. Analisis Statistik: Tingkat Penetrasi & Kesenjangan (Gap)
# ------------------------------------------------------------------------------
cat("\n=== RINGKASAN PENETRASI INTERNET KOTA VS DESA (2020 VS 2022) ===\n")
tabel_wilayah <- df_komparasi_wilayah %>%
  group_by(tipe_daerah, tahun) %>%
  summarise(
    total_penduduk = n(),
    pengguna_net   = sum(pakai_internet, na.rm = TRUE),
    persen_net     = round(mean(pakai_internet, na.rm = TRUE) * 100, 2),
    persen_bobot   = round(weighted.mean(pakai_internet, w = FWT, na.rm = TRUE) * 100, 2),
    .groups        = "drop"
  )
print(tabel_wilayah)

# Hitung Kesenjangan (Gap Perkotaan - Perdesaan)
matriks_wilayah <- tapply(df_komparasi_wilayah$pakai_internet,
                          list(df_komparasi_wilayah$tipe_daerah, df_komparasi_wilayah$tahun),
                          function(x) round(mean(x, na.rm = TRUE) * 100, 2))
matriks_wilayah <- as.data.frame(matriks_wilayah)

cat("\n=== ANALISIS JURANG DIGITAL KOTA VS DESA ===\n")
print(matriks_wilayah)
gap_2020 <- matriks_wilayah["Perkotaan", "2020"] - matriks_wilayah["Perdesaan", "2020"]
gap_2022 <- matriks_wilayah["Perkotaan", "2022"] - matriks_wilayah["Perdesaan", "2022"]
cat(sprintf("Kesenjangan Tahun 2020: %.2f persen poin\n", gap_2020))
cat(sprintf("Kesenjangan Tahun 2022: %.2f persen poin\n", gap_2022))

# Uji Beda Dua Proporsi untuk Tahun 2022 (prop.test)
cat("\n=== UJI BEDA PROPORSI KOTA VS DESA PADA TAHUN 2022 ===\n")
sub_2022 <- tabel_wilayah %>% filter(tahun == 2022)
print(prop.test(x = sub_2022$pengguna_net, n = sub_2022$total_penduduk))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis Komparasi Berdampingan (ggplot2)
# ------------------------------------------------------------------------------
p3 <- ggplot(tabel_wilayah, aes(x = tipe_daerah, y = persen_net, fill = factor(tahun))) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.6) +
  geom_text(aes(label = paste0(persen_net, "%")), 
            position = position_dodge(0.75), vjust = -0.5, fontface = "bold", size = 4.2) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#16a085")) +
  ylim(0, 100) +
  labs(
    title = "Kesenjangan Akses Internet Perkotaan vs Perdesaan (2020 vs 2022)",
    subtitle = "Meskipun Akses di Desa Naik Pesat (+11%), Jurang Digital Tetap Sekitar 19 Persen Poin",
    x = "Wilayah Tempat Tinggal",
    y = "Penetrasi Internet (%)",
    fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    axis.text.x = element_text(face = "bold", size = 11),
    legend.position = "bottom"
  )

print(p3)
