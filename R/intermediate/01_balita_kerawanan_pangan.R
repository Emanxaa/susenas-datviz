# ==============================================================================
# PENELITIAN 1: Balita dan Kerawanan Pangan (SUSENAS 2019-2023)
# Tingkat Kesulitan: Intermediate (Mudah Dipahami & Dijalankan Baris demi Baris)
# ==============================================================================

# 1. Load library yang umum dan mudah digunakan
library(data.table)  # untuk fread() membaca file cepat dan selektif
library(dplyr)       # untuk manipulasi data (mutate, filter, group_by)

# 2. Fungsi untuk mengambil data satu tahun survei
ambil_data_balita <- function(tahun) {
  message(paste(">> Memproses Tahun:", tahun))
  
  # A. Tentukan nama kolom ID: 2019-2021 memakai RENUM, 2022-2023 memakai URUT
  id_col <- ifelse(tahun <= 2021, "RENUM", "URUT")
  
  # B. Bentuk path file secara relatif dari root project
  file_rt <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", 
                       paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  file_ind <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", 
                        paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv"))
  
  # C. Baca file KOR RT: hanya ambil kolom wilayah, FIES (R1701-R1708), dan bobot
  kolom_rt <- c(id_col, "R101", "R102", "R105", "R301", "FWT",
                "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  data_rt <- fread(file_rt, select = kolom_rt)
  
  # D. Baca file KOR INDIVIDU: ambil kolom ID dan Umur (R407)
  kolom_ind <- c(id_col, "R407")
  data_ind <- fread(file_ind, select = kolom_ind)
  
  # E. Hitung jumlah balita (umur < 5 tahun) per rumah tangga
  balita_rt <- data_ind %>%
    group_by(.data[[id_col]]) %>%
    summarise(
      jumlah_balita = sum(R407 < 5, na.rm = TRUE)
    )
  
  # F. Gabungkan KOR RT dengan data balita menggunakan ID
  hasil <- merge(data_rt, balita_rt, by = id_col)
  
  # G. Standarisasi nama ID dan hitung Skor Total FIES (jawaban 1 = Ya, 2 = Tidak)
  hasil <- hasil %>%
    rename(id_rt = all_of(id_col)) %>%
    mutate(
      tahun = tahun,
      # Skor FIES: hitung berapa banyak jawaban "Ya" (kode 1)
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      # Kategori keberadaan balita untuk grafik
      kategori_balita = case_when(
        jumlah_balita == 0 ~ "0 Balita",
        jumlah_balita == 1 ~ "1 Balita",
        jumlah_balita == 2 ~ "2 Balita",
        TRUE ~ "3+ Balita"
      )
    )
  
  return(hasil)
}

# 3. Loop sederhana untuk mengumpulkan data 2019 sampai 2023
daftar_tahun <- 2019:2023
list_semua_tahun <- list()

for (th in daftar_tahun) {
  list_semua_tahun[[as.character(th)]] <- ambil_data_balita(th)
}

# Gabungkan menjadi satu data master 5 tahun
df_balita_fies <- bind_rows(list_semua_tahun)

# 4. Analisis Statistik Klasik
message("
--- STATISTIK DESKRIPTIF: RATA-RATA SKOR FIES MENURUT BALITA ---")
tabel_deskriptif <- df_balita_fies %>%
  group_by(kategori_balita) %>%
  summarise(
    n_sampel = n(),
    rata_skor_fies = mean(skor_fies, na.rm = TRUE),
    sd_skor_fies = sd(skor_fies, na.rm = TRUE)
  )
print(tabel_deskriptif)

message("
--- KORELASI PEARSON ---")
uji_korelasi <- cor.test(df_balita_fies$jumlah_balita, df_balita_fies$skor_fies)
print(uji_korelasi)

message("
--- REGRESI LINEAR SEDERHANA ---")
model_regresi <- lm(skor_fies ~ jumlah_balita + factor(R105) + factor(tahun), data = df_balita_fies)
summary(model_regresi)
