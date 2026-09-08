# ==============================================================================
# PENELITIAN 3: Bantuan Sosial (BPNT, PKH, BPJS PBI) vs FIES (SUSENAS 2019-2023)
# Tingkat Kesulitan: Intermediate (Mudah Dipahami & Dijalankan Baris demi Baris)
# ==============================================================================

library(data.table)
library(dplyr)

ambil_data_bansos <- function(tahun) {
  message(paste(">> Memproses Tahun:", tahun))
  
  # 1. Kunci Relasi (2019-2021: RENUM, 2022-2023: URUT)
  id_col <- ifelse(tahun <= 2021, "RENUM", "URUT")
  
  # 2. Path File Relatif dari Root Project
  file_rt <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", 
                       paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  
  # Catatan BPS: Variabel BPJS PBI (R1101_A) ada di PART2 pada 2019 & 2021, dan di PART1 pada 2020, 2022, 2023
  nama_ind_file <- ifelse(tahun %in% c(2019, 2021), 
                          paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART2.csv"),
                          paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv"))
  file_ind <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", nama_ind_file)
  
  file_kp <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", 
                       paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  # 3. Baca KOR RT
  kolom_rt_standar <- c(id_col, "R101", "R102", "R105", "FWT",
                        "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  hdr_rt <- names(fread(file_rt, nrows = 1))
  kolom_rt <- intersect(c(kolom_rt_standar, "R2105", "R2202", "R2204A", "R2207"), hdr_rt)
  dt_rt <- fread(file_rt, select = kolom_rt)
  
  # 4. Baca BPJS PBI dari Individu (R1101_A: 1 = Memiliki BPJS PBI)
  hdr_ind <- names(fread(file_ind, nrows = 1))
  kolom_ind <- intersect(c(id_col, "R1101_A"), hdr_ind)
  dt_ind <- fread(file_ind, select = kolom_ind)
  
  pbi_rt <- dt_ind %>%
    group_by(.data[[id_col]]) %>%
    summarise(punya_bpjs_pbi = as.integer(any(R1101_A == 1, na.rm = TRUE)))
  
  # 5. Baca Pengeluaran dari KP BP 4.3
  dt_kp <- fread(file_kp, select = c(id_col, "KAPITA", "FOOD", "EXPEND"))
  
  # 6. Gabungkan Ketiga Modul Berdasarkan ID
  gabung1 <- merge(dt_rt, pbi_rt, by = id_col, all.x = TRUE)
  hasil <- merge(gabung1, dt_kp, by = id_col, all.x = TRUE)
  
  # 7. Wrangling Sederhana
  hasil <- hasil %>%
    rename(id_rt = all_of(id_col)) %>%
    mutate(
      tahun = tahun,
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan", "Tahan Pangan")
    )
  
  # Identifikasi Kepesertaan Bansos (KKS / PKH)
  if (tahun == 2019) {
    hasil$penerima_bansos <- ifelse(!is.na(hasil$R2105) & hasil$R2105 == 1, "Penerima", "Bukan Penerima")
  } else {
    is_penerima <- (!is.na(hasil$R2202) & hasil$R2202 == 1) | (!is.na(hasil$R2204A) & hasil$R2204A == 1)
    hasil$penerima_bansos <- ifelse(is_penerima, "Penerima", "Bukan Penerima")
  }
  
  return(hasil)
}

# Loop Mengumpulkan Data 2019-2023
daftar_tahun <- 2019:2023
list_bansos <- list()
for (th in daftar_tahun) {
  list_bansos[[as.character(th)]] <- ambil_data_bansos(th)
}
df_bansos_fies <- bind_rows(list_bansos)

# Analisis Statistik Klasik
message("
--- TABEL KONTINGENSI: STATUS BANSOS VS RAWAN PANGAN ---")
tabel_bansos <- table(df_bansos_fies$penerima_bansos, df_bansos_fies$status_rawan)
print(tabel_bansos)

message("
--- UJI CHI-SQUARE (BANSOS VS FIES) ---")
print(chisq.test(tabel_bansos))

message("
--- UJI-T BEDA RATA-RATA SKOR FIES (PENERIMA VS BUKAN) ---")
print(t.test(skor_fies ~ penerima_bansos, data = df_bansos_fies))
