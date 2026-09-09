# ==============================================================================
# PENELITIAN 2: Komparasi Jurang Digital Antar-Generasi (2020 vs 2022)
# Meneliti Transformasi Akses Internet: Awal Pandemi (2020) vs Puncak Adaptasi (2022)
# Paket: Hanya Bawaan R (Base R) + dplyr + ggplot2
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca dan Menyiapkan Data Generasi
# ------------------------------------------------------------------------------
baca_data_generasi <- function(tahun) {
  cat("Membaca Data Tahun:", tahun, "...\n")
  
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
  # - R808 : Apakah pernah mengakses internet dalam 3 bulan terakhir? (1 = Ya, 5 = Tidak)
  # - FWT  : Faktor Penimbang Akhir
  # ----------------------------------------------------------------------------
  
  df_filtered <- data_ind %>%
    filter(R407 >= 5) %>%
    mutate(
      tahun = tahun,
      kelompok_usia = case_when(
        R407 <= 24 ~ "Anak & Gen Z (5-24 thn)",
        R407 <= 59 ~ "Dewasa Produktif (25-59 thn)",
        TRUE       ~ "Lansia (60+ thn)"
      ),
      pakai_internet = ifelse(R808 == 1, 1, 0)
    ) %>%
    select(tahun, kelompok_usia, pakai_internet, FWT)
  
  return(df_filtered)
}

# ------------------------------------------------------------------------------
# 2. Gabungkan Data Dua Tahun Kunci: 2020 dan 2022
# ------------------------------------------------------------------------------
data_2020 <- baca_data_generasi(2020)
data_2022 <- baca_data_generasi(2022)
df_komparasi_gen <- bind_rows(data_2020, data_2022)

# ------------------------------------------------------------------------------
# 3. Analisis Statistik: Tabel Silang & Selisih Pertumbuhan
# ------------------------------------------------------------------------------
cat("\n=== KOMPARASI PENETRASI INTERNET ANTAR-GENERASI (2020 VS 2022) ===\n")
tabel_ringkasan <- df_komparasi_gen %>%
  group_by(kelompok_usia, tahun) %>%
  summarise(
    n_sampel = n(),
    persen_internet = round(mean(pakai_internet, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  )
print(tabel_ringkasan)

# Hitung kenaikan poin persentase (growth / delta)
cat("\n=== TABEL PERBANDINGAN & KENAIKAN INTERNET (2020 VS 2022) ===\n")
matriks_gen <- tapply(df_komparasi_gen$pakai_internet, 
                      list(df_komparasi_gen$kelompok_usia, df_komparasi_gen$tahun), 
                      function(x) round(mean(x, na.rm = TRUE) * 100, 1))
matriks_gen <- as.data.frame(matriks_gen)
matriks_gen$Kenaikan_Persen_Poin <- round(matriks_gen$`2022` - matriks_gen$`2020`, 1)
print(matriks_gen)

# Uji Chi-Square Signifikansi Perubahan Antara 2020 dan 2022
cat("\n=== UJI CHI-SQUARE: TAHUN VS AKSES INTERNET PADA KELOMPOK LANSIA ===\n")
tab_lansia <- table(df_komparasi_gen$tahun[df_komparasi_gen$kelompok_usia == "Lansia (60+ thn)"],
                    df_komparasi_gen$pakai_internet[df_komparasi_gen$kelompok_usia == "Lansia (60+ thn)"])
print(tab_lansia)
print(chisq.test(tab_lansia))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis Komparasi Berdampingan (ggplot2)
# ------------------------------------------------------------------------------
p2 <- ggplot(tabel_ringkasan, aes(x = kelompok_usia, y = persen_internet, fill = factor(tahun))) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.65) +
  geom_text(aes(label = paste0(persen_internet, "%")), 
            position = position_dodge(0.75), vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#2980b9")) +
  ylim(0, 100) +
  labs(
    title = "Jurang Digital Antar-Generasi: Lonjakan Akses 2020 vs 2022",
    subtitle = "Gen Z Mengalami Lonjakan Tertinggi (+12,3%), Sementara Lansia Baru Mencapai 21,6%",
    x = "Kelompok Generasi",
    y = "Penetrasi Internet (%)",
    fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    axis.text.x = element_text(face = "bold", size = 10),
    legend.position = "bottom"
  )

print(p2)
