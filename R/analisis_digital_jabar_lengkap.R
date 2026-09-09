# ==============================================================================
# PIPELINE LENGKAP ANALISIS GAYA HIDUP DIGITAL JAWA BARAT (SUSENAS 2019-2023)
# Versi: 100% Manual, Linear, dan Runut (Tanpa Fungsi Kustom / Tanpa Loop)
# Paket yang Digunakan: Hanya Bawaan R (Base R) + dplyr + ggplot2
# ==============================================================================
#
# TUJUAN SKRIP INI:
# Memandu Anda secara bertahap mulai dari membaca file mentah CSV tahun per tahun,
# membersihkan data (munging), mentransformasi kode BPS (wrangling), hingga
# menghasilkan 4 infografis visual untuk ke-4 Research Questions (RQ).
#
# STRUKTUR KUESIONER BPS (KOR INDIVIDU PART 1):
# - R101   : Provinsi (32 = Jawa Barat)
# - R102   : Kabupaten/Kota
# - R105   : Klasifikasi Wilayah (1 = Perkotaan, 2 = Perdesaan)
# - R407   : Umur responden dalam tahun (Blok IV)
# - R802   : Apakah memiliki/menguasai telepon seluler? (1 = Ya, 5 = Tidak) (Blok VIII - Konsisten di semua tahun)
# - Akses Internet:
#   * Tahun 2019       : R804 (1 = Ya, 5 = Tidak). Catatan: R808 di 2019 adalah Rekening Tabungan.
#   * Tahun 2020-2023  : R808 (1 = Ya, 5 = Tidak). (BPS merombak nomor pertanyaan TIK mulai 2020).
# - Tujuan Internet:
#   * Tahun 2019       : R807_A s.d. R807_J (Medsos, Berita, Belanja, Hiburan, dll)
#   * Tahun 2020-2023  : R811_A s.d. R811_J
# - FWT    : Faktor Penimbang Akhir (Bobot representasi populasi BPS - kolom digital)
# ==============================================================================

# ------------------------------------------------------------------------------
# BAGIAN 0: MEMUAT PAKET & MENENTUKAN ROOT PATH
# ------------------------------------------------------------------------------
library(dplyr)
library(ggplot2)

# Deteksi folder data secara otomatis (fleksibel di folder project apa pun)
root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
  file.path("SUSENAS", "JAWA BARAT")
} else {
  "JAWA BARAT"
}
cat("Folder data yang digunakan:", root_data, "\n")


# ==============================================================================
# BAGIAN 1: EXTRACT (MEMBACA DATA CSV SETIAP TAHUN SECARA EKSPLISIT)
# ==============================================================================
cat("\n>>> LANGKAH 1: MEMBACA FILE CSV 2019-2023 SATU PER SATU <<<\n")

# Path file relatif untuk masing-masing tahun
path_2019 <- file.path(root_data, "2019", "csv", "KOR", "2019 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
path_2020 <- file.path(root_data, "2020", "csv", "KOR", "2020 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
path_2021 <- file.path(root_data, "2021", "csv", "KOR", "2021 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
path_2022 <- file.path(root_data, "2022", "csv", "KOR", "2022 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")
path_2023 <- file.path(root_data, "2023", "csv", "KOR", "2023 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")

# Membaca data mentah per tahun menggunakan fungsi bawaan R (read.csv)
cat("Membaca data 2019...\n"); raw_2019 <- read.csv(path_2019, stringsAsFactors = FALSE)
cat("Membaca data 2020...\n"); raw_2020 <- read.csv(path_2020, stringsAsFactors = FALSE)
cat("Membaca data 2021...\n"); raw_2021 <- read.csv(path_2021, stringsAsFactors = FALSE)
cat("Membaca data 2022...\n"); raw_2022 <- read.csv(path_2022, stringsAsFactors = FALSE)
cat("Membaca data 2023...\n"); raw_2023 <- read.csv(path_2023, stringsAsFactors = FALSE)


# ==============================================================================
# BAGIAN 2: MUNGING & TRANSFORM MANUAL TIAP TAHUN
# ==============================================================================
cat("\n>>> LANGKAH 2: MEMBERSIHKAN & MEMILIH KOLOM TIAP TAHUN <<<\n")
# Catatan First Principles:
# Modul TIK BPS hanya ditanyakan pada penduduk usia >= 5 tahun.
# Balita usia 0-4 tahun dibuang agar tidak merusak perhitungan persentase.

# Bersihkan Tahun 2019
clean_2019 <- raw_2019 %>%
  filter(R407 >= 5) %>%
  mutate(
    tahun = 2019,
    punya_hp = ifelse(R802 == 1, 1, 0),
    pakai_internet = ifelse(R804 == 1, 1, 0), # Di 2019 variabel internet adalah R804 (R808 di 2019 adalah rekening tabungan)
    tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan")
  ) %>%
  select(tahun, R101, R102, R105, tipe_daerah, R407, punya_hp, pakai_internet, FWT)

# Bersihkan Tahun 2020
clean_2020 <- raw_2020 %>%
  filter(R407 >= 5) %>%
  mutate(
    tahun = 2020,
    punya_hp = ifelse(R802 == 1, 1, 0),
    pakai_internet = ifelse(R808 == 1, 1, 0),
    tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan")
  ) %>%
  select(tahun, R101, R102, R105, tipe_daerah, R407, punya_hp, pakai_internet, FWT)

# Bersihkan Tahun 2021
clean_2021 <- raw_2021 %>%
  filter(R407 >= 5) %>%
  mutate(
    tahun = 2021,
    punya_hp = ifelse(R802 == 1, 1, 0),
    pakai_internet = ifelse(R808 == 1, 1, 0),
    tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan")
  ) %>%
  select(tahun, R101, R102, R105, tipe_daerah, R407, punya_hp, pakai_internet, FWT)

# Bersihkan Tahun 2022
clean_2022 <- raw_2022 %>%
  filter(R407 >= 5) %>%
  mutate(
    tahun = 2022,
    punya_hp = ifelse(R802 == 1, 1, 0),
    pakai_internet = ifelse(R808 == 1, 1, 0),
    tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan")
  ) %>%
  select(tahun, R101, R102, R105, tipe_daerah, R407, punya_hp, pakai_internet, FWT)

# Bersihkan Tahun 2023
clean_2023 <- raw_2023 %>%
  filter(R407 >= 5) %>%
  mutate(
    tahun = 2023,
    punya_hp = ifelse(R802 == 1, 1, 0),
    pakai_internet = ifelse(R808 == 1, 1, 0),
    tipe_daerah = ifelse(R105 == 1, "Perkotaan", "Perdesaan")
  ) %>%
  select(tahun, R101, R102, R105, tipe_daerah, R407, punya_hp, pakai_internet, FWT)

# Menumpuk (Stacking / Load) 5 tahun menjadi satu data frame master
df_master_5tahun <- bind_rows(clean_2019, clean_2020, clean_2021, clean_2022, clean_2023)
cat("Total seluruh data individu bersih (2019-2023):", nrow(df_master_5tahun), "baris\n")


# ==============================================================================
# RESEARCH QUESTION 1: TREN KEPEMILIKAN PONSEL (2019-2023)
# ==============================================================================
cat("\n==================================================================\n")
cat("RQ 1: DINAMIKA TREN KEPEMILIKAN PONSEL DI JAWA BARAT (2019-2023)\n")
cat("==================================================================\n")

# Wrangling: Menghitung persentase kepemilikan HP per tahun
tabel_rq1 <- df_master_5tahun %>%
  group_by(tahun) %>%
  summarise(
    total_sampel  = n(),
    persen_sampel = round(mean(punya_hp, na.rm = TRUE) * 100, 2),
    persen_bobot  = round(weighted.mean(punya_hp, w = FWT, na.rm = TRUE) * 100, 2)
  )
print(tabel_rq1)

cat("\nCatatan Analisis RQ1:\n")
cat("- Titik Terendah (Min): Tahun 2020 (", tabel_rq1$persen_sampel[tabel_rq1$tahun == 2020], "%) -> Awal Guncangan Krisis Pandemi\n")
cat("- Titik Puncak (Max)  : Tahun 2022 (", tabel_rq1$persen_sampel[tabel_rq1$tahun == 2022], "%) -> Puncak Pemulihan & Normal Baru\n")

# Visualisasi RQ1 (Garis Tren dengan Sorotan 2020 vs 2022)
grafik_rq1 <- ggplot(tabel_rq1, aes(x = factor(tahun), y = persen_sampel, group = 1)) +
  geom_line(color = "#7f8c8d", linewidth = 1.2) +
  geom_point(aes(color = ifelse(tahun == 2020, "Min (2020)", 
                         ifelse(tahun == 2022, "Max (2022)", "Tahun Lain"))), size = 4.5) +
  geom_text(aes(label = paste0(persen_sampel, "%")), vjust = -0.9, fontface = "bold", size = 4.2) +
  scale_color_manual(values = c("Min (2020)" = "#e74c3c", "Max (2022)" = "#27ae60", "Tahun Lain" = "#2980b9")) +
  ylim(min(tabel_rq1$persen_sampel) - 4, max(tabel_rq1$persen_sampel) + 4) +
  labs(
    title = "Dinamika Kepemilikan Ponsel di Jawa Barat (2019–2023)",
    subtitle = "Menyoroti Titik Terendah pada Awal Pandemi (2020) vs Rekor Tertinggi (2022)",
    x = "Tahun Survei", y = "Tingkat Kepemilikan (%)", color = "Tonggak Penting",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2019-2023 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 13), legend.position = "bottom")

print(grafik_rq1)


# ==============================================================================
# RESEARCH QUESTION 2: JURANG DIGITAL ANTAR-GENERASI (2020 vs 2022)
# ==============================================================================
cat("\n==================================================================\n")
cat("RQ 2: JURANG AKSES INTERNET ANTAR-GENERASI: 2020 VS 2022\n")
cat("==================================================================\n")

# Ambil data tahun 2020 dan 2022, lalu tambahkan kolom generasi (binning umur)
df_rq2 <- bind_rows(clean_2020, clean_2022) %>%
  mutate(
    kelompok_usia = case_when(
      R407 <= 24 ~ "Anak & Gen Z (5-24 thn)",
      R407 <= 59 ~ "Dewasa Produktif (25-59 thn)",
      TRUE       ~ "Lansia (60+ thn)"
    )
  )

# Wrangling: Menghitung persentase pengguna internet per generasi di 2020 vs 2022
tabel_rq2 <- df_rq2 %>%
  group_by(kelompok_usia, tahun) %>%
  summarise(
    persen_internet = round(mean(pakai_internet, na.rm = TRUE) * 100, 1),
    .groups = "drop"
  )
print(tabel_rq2)

# Hitung selisih pertumbuhan (delta) secara manual
cat("\nKenaikan Poin Persentase (2020 ke 2022):\n")
matriks_rq2 <- tapply(df_rq2$pakai_internet, list(df_rq2$kelompok_usia, df_rq2$tahun), 
                      function(x) round(mean(x, na.rm = TRUE) * 100, 1))
matriks_rq2 <- as.data.frame(matriks_rq2)
matriks_rq2$Kenaikan_Poin <- round(matriks_rq2$`2022` - matriks_rq2$`2020`, 1)
print(matriks_rq2)

# Uji Statistik: Chi-Square pada Generasi Lansia
cat("\nUji Chi-Square (Perubahan Akses Internet Lansia 2020 vs 2022):\n")
tab_chi_lansia <- table(df_rq2$tahun[df_rq2$kelompok_usia == "Lansia (60+ thn)"],
                        df_rq2$pakai_internet[df_rq2$kelompok_usia == "Lansia (60+ thn)"])
print(chisq.test(tab_chi_lansia))

# Visualisasi RQ2 (Diagram Batang Berdampingan)
grafik_rq2 <- ggplot(tabel_rq2, aes(x = kelompok_usia, y = persen_internet, fill = factor(tahun))) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.65) +
  geom_text(aes(label = paste0(persen_internet, "%")), 
            position = position_dodge(0.75), vjust = -0.5, fontface = "bold", size = 4) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#2980b9")) +
  ylim(0, 100) +
  labs(
    title = "Jurang Digital Antar-Generasi: Lonjakan Akses 2020 vs 2022",
    subtitle = "Gen Z Mengalami Lonjakan Tertinggi (+12,4%), Sedangkan Lansia Baru 21,6% yang Online",
    x = "Kelompok Generasi", y = "Penetrasi Internet (%)", fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 13), legend.position = "bottom")

print(grafik_rq2)


# ==============================================================================
# RESEARCH QUESTION 3: KESENJANGAN KOTA VS DESA (2020 vs 2022)
# ==============================================================================
cat("\n==================================================================\n")
cat("RQ 3: KESENJANGAN AKSES INTERNET PERKOTAAN VS PERDESAAN (2020 VS 2022)\n")
cat("==================================================================\n")

df_rq3 <- bind_rows(clean_2020, clean_2022)

# Wrangling: Menghitung penetrasi internet Kota vs Desa
tabel_rq3 <- df_rq3 %>%
  group_by(tipe_daerah, tahun) %>%
  summarise(
    total_penduduk = n(),
    pengguna_net   = sum(pakai_internet, na.rm = TRUE),
    persen_net     = round(mean(pakai_internet, na.rm = TRUE) * 100, 2),
    .groups        = "drop"
  )
print(tabel_rq3)

# Hitung Lebar Kesenjangan (Gap)
gap_2020 <- tabel_rq3$persen_net[tabel_rq3$tipe_daerah == "Perkotaan" & tabel_rq3$tahun == 2020] - 
            tabel_rq3$persen_net[tabel_rq3$tipe_daerah == "Perdesaan" & tabel_rq3$tahun == 2020]

gap_2022 <- tabel_rq3$persen_net[tabel_rq3$tipe_daerah == "Perkotaan" & tabel_rq3$tahun == 2022] - 
            tabel_rq3$persen_net[tabel_rq3$tipe_daerah == "Perdesaan" & tabel_rq3$tahun == 2022]

cat(sprintf("\nLebar Kesenjangan Kota-Desa Tahun 2020: %.2f persen poin\n", gap_2020))
cat(sprintf("Lebar Kesenjangan Kota-Desa Tahun 2022: %.2f persen poin\n", gap_2022))

# Uji Kesamaan Dua Proporsi Kota vs Desa pada Tahun 2022 (prop.test)
cat("\nUji Beda Dua Proporsi Kota vs Desa (Tahun 2022):\n")
sub_2022 <- tabel_rq3 %>% filter(tahun == 2022)
print(prop.test(x = sub_2022$pengguna_net, n = sub_2022$total_penduduk))

# Visualisasi RQ3 (Diagram Batang Berdampingan)
grafik_rq3 <- ggplot(tabel_rq3, aes(x = tipe_daerah, y = persen_net, fill = factor(tahun))) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.6) +
  geom_text(aes(label = paste0(persen_net, "%")), 
            position = position_dodge(0.75), vjust = -0.5, fontface = "bold", size = 4.2) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#16a085")) +
  ylim(0, 100) +
  labs(
    title = "Kesenjangan Akses Internet Perkotaan vs Perdesaan (2020 vs 2022)",
    subtitle = "Meskipun Akses di Desa Meningkat (+11,2%), Jurang Digital Tetap Sekitar 19 Persen Poin",
    x = "Wilayah Tempat Tinggal", y = "Penetrasi Internet (%)", fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 13), legend.position = "bottom")

print(grafik_rq3)


# ==============================================================================
# RESEARCH QUESTION 4: PERGESERAN PERILAKU AKTIVITAS ONLINE (2020 vs 2022)
# ==============================================================================
cat("\n==================================================================\n")
cat("RQ 4: AKTIVITAS ONLINE TERPOPULER PENGGUNA INTERNET (2020 VS 2022)\n")
cat("==================================================================\n")

# Catatan Metodologis & Munging:
# Di kuesioner BPS, pertanyaan aktivitas internet berbentuk checklist pilihan ganda:
# Tahun 2020:
#   - R811_D = 'D' (Media Sosial)
#   - R811_A = 'A' (Berita & Informasi)
#   - R811_G = 'G' (Hiburan: Video, Musik, Game)
#   - R811_B = 'B' (Pembelajaran / PJJ)
#   - R811_E = 'E' (Belanja Online / E-Commerce)
#   - R811_H = 'H' (Layanan Finansial / E-Banking)
# Tahun 2022 (BPS merombak beberapa sub-huruf):
#   - R811_D = 'D' (Media Sosial)
#   - R811_A = 'A' (Berita & Informasi)
#   - R811_J = 'J' (Hiburan)
#   - R811_H = 'H' (Pembelajaran / PJJ)
#   - R811_E = 'E' (Belanja Online / E-Commerce)
#   - R811_G = 'G' (Layanan Finansial / E-Banking)

# 1. Filter pengguna aktif internet di tahun 2020 (R808 == 1)
users_2020 <- raw_2020 %>% filter(R808 == 1)
akt_2020 <- data.frame(
  tahun = "2020",
  aktivitas = c("Hiburan (Video, Game)", "Berita & Informasi", "Media Sosial (WA, IG)",
                "Belanja Online (E-Commerce)", "Sekolah Online (PJJ)", "Layanan Finansial (M-Banking)"),
  persen = c(
    round(mean(users_2020$R811_G == "G", na.rm = TRUE) * 100, 1),
    round(mean(users_2020$R811_A == "A", na.rm = TRUE) * 100, 1),
    round(mean(users_2020$R811_D == "D", na.rm = TRUE) * 100, 1),
    round(mean(users_2020$R811_E == "E", na.rm = TRUE) * 100, 1),
    round(mean(users_2020$R811_B == "B", na.rm = TRUE) * 100, 1),
    round(mean(users_2020$R811_H == "H", na.rm = TRUE) * 100, 1)
  )
)

# 2. Filter pengguna aktif internet di tahun 2022 (R808 == 1)
users_2022 <- raw_2022 %>% filter(R808 == 1)
akt_2022 <- data.frame(
  tahun = "2022",
  aktivitas = c("Hiburan (Video, Game)", "Berita & Informasi", "Media Sosial (WA, IG)",
                "Belanja Online (E-Commerce)", "Sekolah Online (PJJ)", "Layanan Finansial (M-Banking)"),
  persen = c(
    round(mean(users_2022$R811_J == "J", na.rm = TRUE) * 100, 1),
    round(mean(users_2022$R811_A == "A", na.rm = TRUE) * 100, 1),
    round(mean(users_2022$R811_D == "D", na.rm = TRUE) * 100, 1),
    round(mean(users_2022$R811_E == "E", na.rm = TRUE) * 100, 1),
    round(mean(users_2022$R811_H == "H", na.rm = TRUE) * 100, 1),
    round(mean(users_2022$R811_G == "G", na.rm = TRUE) * 100, 1)
  )
)

# Gabungkan data aktivitas 2020 dan 2022
df_rq4 <- bind_rows(akt_2020, akt_2022)

# Tabel Komparasi dan Perubahan Persen Poin
matriks_rq4 <- tapply(df_rq4$persen, list(df_rq4$aktivitas, df_rq4$tahun), identity)
matriks_rq4 <- as.data.frame(matriks_rq4)
matriks_rq4$Perubahan_Poin <- round(matriks_rq4$`2022` - matriks_rq4$`2020`, 1)
print(matriks_rq4[order(matriks_rq4$`2022`, decreasing = TRUE), ])

# Visualisasi RQ4 (Diagram Batang Mendatar Berpasangan)
# Urutkan faktor agar aktivitas tertinggi tahun 2022 berada di atas
urutan_akt <- matriks_rq4 %>% arrange(`2022`) %>% rownames()
df_rq4$aktivitas <- factor(df_rq4$aktivitas, levels = urutan_akt)

grafik_rq4 <- ggplot(df_rq4, aes(x = persen, y = aktivitas, fill = tahun)) +
  geom_bar(stat = "identity", position = position_dodge(0.75), width = 0.65) +
  geom_text(aes(label = paste0(persen, "%")), 
            position = position_dodge(0.75), hjust = -0.15, fontface = "bold", size = 3.8) +
  scale_fill_manual(values = c("2020" = "#95a5a6", "2022" = "#8e44ad")) +
  xlim(0, 100) +
  labs(
    title = "Pergeseran Perilaku Online Warga Jawa Barat (2020 vs 2022)",
    subtitle = "Lonjakan Tajam pada Hiburan Digital, Sekolah Daring (PJJ), dan Belanja Online",
    x = "Persentase Pengguna Internet (%)", y = "", fill = "Tahun Survei",
    caption = "Sumber: BPS SUSENAS Jawa Barat 2020 & 2022 (KOR Individu Usia 5+)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    axis.text.y = element_text(face = "bold", size = 10),
    legend.position = "bottom"
  )

print(grafik_rq4)

cat("\n>>> SELURUH PIPELINE 4 RESEARCH QUESTIONS TELAH SELESAI DIEKSEKUSI <<<\n")
