# ==============================================================================
# PENELITIAN 1: Tren Kepemilikan Ponsel di Jawa Barat (SUSENAS 2019-2023)
# Sorotan Khusus: Titik Terendah (2020) vs Titik Puncak (2022)
# Paket: Hanya Bawaan R (Base R) + dplyr + ggplot2
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data Individu per Tahun
# ------------------------------------------------------------------------------
ambil_data_hp <- function(tahun) {
  cat("Memproses Tahun:", tahun, "\n")
  
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
  # - R407 : Umur responden dalam tahun (Blok IV)
  # - R802 : Apakah memiliki/menguasai telepon seluler? (1 = Ya, 5 = Tidak) (Blok VIII)
  # - FWT  : Faktor Penimbang Akhir (Bobot Representasi Populasi BPS)
  # ----------------------------------------------------------------------------
  
  # Filter penduduk usia 5 tahun ke atas (standar BPS untuk modul TIK)
  hasil <- data_ind %>%
    filter(R407 >= 5) %>%
    mutate(
      tahun = tahun,
      punya_hp = ifelse(R802 == 1, 1, 0)
    ) %>%
    select(tahun, R101, R102, R105, R407, punya_hp, FWT)
  
  return(hasil)
}

# ------------------------------------------------------------------------------
# 2. Kumpulkan Data 5 Tahun Penuh (2019-2023)
# ------------------------------------------------------------------------------
daftar_tahun <- 2019:2023
list_data <- list()

for (th in daftar_tahun) {
  list_data[[as.character(th)]] <- ambil_data_hp(th)
}

df_tren_hp <- bind_rows(list_data)
cat("\nTotal Responden Dianalisis (Usia 5+):", nrow(df_tren_hp), "baris\n")

# ------------------------------------------------------------------------------
# 3. Ringkasan Statistik Tahunan & Uji Tren
# ------------------------------------------------------------------------------
cat("\n=== TINGKAT KEPEMILIKAN PONSEL TAHUNAN DI JAWA BARAT ===\n")
tabel_tren <- df_tren_hp %>%
  group_by(tahun) %>%
  summarise(
    jumlah_sampel = n(),
    persen_sampel = round(mean(punya_hp, na.rm = TRUE) * 100, 2),
    persen_terbobot_fwt = round(weighted.mean(punya_hp, w = FWT, na.rm = TRUE) * 100, 2)
  )
print(tabel_tren)

# Keterangan tonggak sejarah:
cat("\n* Catatan Analisis:")
cat("\n- Titik Terendah (Minimum) : Tahun 2020 (", tabel_tren$persen_sampel[tabel_tren$tahun == 2020], "%) -> Awal Guncangan Pandemi")
cat("\n- Titik Tertinggi (Maksimum): Tahun 2022 (", tabel_tren$persen_sampel[tabel_tren$tahun == 2022], "%) -> Puncak Adaptasi Digital & PJJ\n\n")

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis (ggplot2)
# ------------------------------------------------------------------------------
p1 <- ggplot(tabel_tren, aes(x = factor(tahun), y = persen_sampel, group = 1)) +
  geom_line(color = "#7f8c8d", linewidth = 1.2) +
  geom_point(aes(color = ifelse(tahun == 2020, "Min (2020)", 
                         ifelse(tahun == 2022, "Max (2022)", "Tahun Lain"))), size = 4.5) +
  geom_text(aes(label = paste0(persen_sampel, "%")), vjust = -0.9, fontface = "bold", size = 4.3) +
  scale_color_manual(values = c("Min (2020)" = "#e74c3c", "Max (2022)" = "#27ae60", "Tahun Lain" = "#2980b9")) +
  ylim(min(tabel_tren$persen_sampel) - 4, max(tabel_tren$persen_sampel) + 4) +
  labs(
    title = "Dinamika Kepemilikan Ponsel di Jawa Barat (2019–2023)",
    subtitle = "Menyoroti Titik Terendah pada Awal Pandemi (2020) vs Rekor Tertinggi (2022)",
    x = "Tahun Survei",
    y = "Tingkat Kepemilikan (%)",
    color = "Tonggak Penting",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2019-2023 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom"
  )

print(p1)
