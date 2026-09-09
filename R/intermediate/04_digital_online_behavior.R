# ==============================================================================
# PENELITIAN 4: Perubahan Perilaku Aktivitas Online Warga Jabar (2020 vs 2022)
# Meneliti Aktivitas Apa yang Meledak Selama Pandemi (Belanja Online, Hiburan, Belajar)
# Paket: Hanya Bawaan R (Base R) + dplyr + ggplot2
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Menghitung Proporsi Aktivitas Online per Tahun
# ------------------------------------------------------------------------------
hitung_aktivitas_online <- function(tahun) {
  cat("Memproses Aktivitas Online Tahun:", tahun, "...\n")
  
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
  # METADATA & LABEL RESMI BPS (VSEN.K BLOK VIII - TUJUAN PENGGUNAAN INTERNET):
  # - R808   : Pengguna aktif internet (1 = Ya)
  # - R811_J : Hiburan (Video, musik, game online) [Kode J]
  # - R811_A : Mendapat informasi / berita [Kode A]
  # - R811_D : Media sosial / jejaring sosial (WA, IG, FB, TikTok) [Kode D]
  # ----------------------------------------------------------------------------
  # Validasi Metadata Resmi BPS:
  # Tahun 2020: Hiburan = R811_G ('G'), PJJ = R811_B ('B'), Finansial = R811_H ('H')
  # Tahun 2022: Hiburan = R811_J ('J'), PJJ = R811_H ('H'), Finansial = R811_G ('G')
  # Konsisten di kedua tahun: Medsos = R811_D ('D'), Berita = R811_A ('A'), Belanja = R811_E ('E')
  # ----------------------------------------------------------------------------
  
  users <- data_ind %>% filter(R407 >= 5 & R808 == 1)
  n_users <- nrow(users)
  
  if (tahun == 2020) {
    p_hiburan   <- round(mean(users$R811_G == "G", na.rm = TRUE) * 100, 1)
    p_berita    <- round(mean(users$R811_A == "A", na.rm = TRUE) * 100, 1)
    p_medsos    <- round(mean(users$R811_D == "D", na.rm = TRUE) * 100, 1)
    p_belanja   <- round(mean(users$R811_E == "E", na.rm = TRUE) * 100, 1)
    p_sekolah   <- round(mean(users$R811_B == "B", na.rm = TRUE) * 100, 1)
    p_finansial <- round(mean(users$R811_H == "H", na.rm = TRUE) * 100, 1)
  } else {
    p_hiburan   <- round(mean(users$R811_J == "J", na.rm = TRUE) * 100, 1)
    p_berita    <- round(mean(users$R811_A == "A", na.rm = TRUE) * 100, 1)
    p_medsos    <- round(mean(users$R811_D == "D", na.rm = TRUE) * 100, 1)
    p_belanja   <- round(mean(users$R811_E == "E", na.rm = TRUE) * 100, 1)
    p_sekolah   <- round(mean(users$R811_H == "H", na.rm = TRUE) * 100, 1)
    p_finansial <- round(mean(users$R811_G == "G", na.rm = TRUE) * 100, 1)
  }
  
  df_hasil <- data.frame(
    tahun = as.character(tahun),
    aktivitas = c(
      "Hiburan (Video, Musik, Game)",
      "Berita & Informasi",
      "Media Sosial (WA, IG, TikTok)",
      "Belanja Online (E-Commerce)",
      "Pembelajaran Online (PJJ)",
      "Layanan Finansial (M-Banking)"
    ),
    persen = c(p_hiburan, p_berita, p_medsos, p_belanja, p_sekolah, p_finansial)
  )
  return(df_hasil)
}

# ------------------------------------------------------------------------------
# 2. Gabungkan Data 2020 dan 2022
# ------------------------------------------------------------------------------
akt_2020 <- hitung_aktivitas_online(2020)
akt_2022 <- hitung_aktivitas_online(2022)
df_komparasi_akt <- bind_rows(akt_2020, akt_2022)

# ------------------------------------------------------------------------------
# 3. Analisis Statistik: Tabel Perbandingan & Kenaikan
# ------------------------------------------------------------------------------
cat("\n=== KOMPARASI AKTIVITAS ONLINE PENGGUNA INTERNET (2020 VS 2022) ===\n")
matriks_akt <- tapply(df_komparasi_akt$persen,
                      list(df_komparasi_akt$aktivitas, df_komparasi_akt$tahun),
                      identity)
matriks_akt <- as.data.frame(matriks_akt)
matriks_akt$Perubahan_Persen_Poin <- round(matriks_akt$`2022` - matriks_akt$`2020`, 1)
print(matriks_akt[order(matriks_akt$`2022`, decreasing = TRUE), ])

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis Batang Horizontal Berpasangan (ggplot2)
# ------------------------------------------------------------------------------
# Urutkan faktor aktivitas berdasarkan nilai tahun 2022
urutan_aktivitas <- matriks_akt %>% 
  arrange(`2022`) %>% 
  rownames()
df_komparasi_akt$aktivitas <- factor(df_komparasi_akt$aktivitas, levels = urutan_aktivitas)

p4 <- ggplot(df_komparasi_akt, aes(x = persen, y = aktivitas, fill = tahun)) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.65) +
  geom_text(aes(label = paste0(persen, "%")), 
            position = position_dodge(0.75), hjust = -0.15, fontface = "bold", size = 3.8) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#8e44ad")) +
  xlim(0, 100) +
  labs(
    title = "Pergeseran Perilaku Online Warga Jawa Barat (2020 vs 2022)",
    subtitle = "Konsumsi Berita & E-Commerce Meningkat, Sementara Media Sosial Tetap Menjadi Aktivitas Utama",
    x = "Persentase Pengguna Internet (%)",
    y = "",
    fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (Pengguna Internet Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    axis.text.y = element_text(face = "bold", size = 10),
    legend.position = "bottom"
  )

print(p4)
