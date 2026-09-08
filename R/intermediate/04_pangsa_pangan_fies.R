# ==============================================================================
# PENELITIAN 4: Pangsa Pengeluaran Pangan (Hukum Engel) vs FIES (2019-2023)
# Tingkat Kesulitan: Intermediate (Mudah Dipahami & Dijalankan Baris demi Baris)
# ==============================================================================

library(data.table)
library(dplyr)

ambil_data_pangsa <- function(tahun) {
  message(paste(">> Memproses Tahun:", tahun))
  
  id_col <- ifelse(tahun <= 2021, "RENUM", "URUT")
  
  file_rt <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", 
                       paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  file_kp <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", 
                       paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  # Ambil skor FIES dari KOR RT
  kolom_rt <- c(id_col, "R101", "R102", "R105", "R301", "FWT",
                "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  dt_rt <- fread(file_rt, select = kolom_rt)
  
  # Ambil rincian pengeluaran dari KP BP 4.3
  kolom_kp <- c(id_col, "FOOD", "NONFOOD", "EXPEND", "KAPITA", "KALORI_KAP", "PROTE_KAP")
  dt_kp <- fread(file_kp, select = kolom_kp)
  
  # Gabungkan kedua file
  hasil <- merge(dt_rt, dt_kp, by = id_col)
  
  hasil <- hasil %>%
    rename(id_rt = all_of(id_col)) %>%
    mutate(
      tahun = tahun,
      # Skor FIES
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      
      # Pangsa Pengeluaran Pangan (PPP) dalam Persen (%)
      pangsa_pangan = (FOOD / EXPEND) * 100,
      
      # Ambang Batas Engel Klasik (60%)
      kelompok_engel = ifelse(pangsa_pangan >= 60, "PPP >= 60% (Rawan Tinggi)", "PPP < 60% (Tahan Pangan)")
    ) %>%
    # Filter data valid
    filter(EXPEND > 0, !is.na(pangsa_pangan), pangsa_pangan <= 100)
  
  return(hasil)
}

daftar_tahun <- 2019:2023
list_pangsa <- list()
for (th in daftar_tahun) {
  list_pangsa[[as.character(th)]] <- ambil_data_pangsa(th)
}
df_pangsa_fies <- bind_rows(list_pangsa)

# Analisis Statistik Klasik
message("
--- KORELASI PEARSON (PANGSA PANGAN VS SKOR FIES) ---")
uji_korelasi_engel <- cor.test(df_pangsa_fies$pangsa_pangan, df_pangsa_fies$skor_fies)
print(uji_korelasi_engel)

message("
--- UJI-T BEDA SKOR FIES (PPP >= 60% VS < 60%) ---")
uji_t_engel <- t.test(skor_fies ~ kelompok_engel, data = df_pangsa_fies)
print(uji_t_engel)

message("
--- REGRESI LINEAR SEDERHANA ---")
model_engel <- lm(skor_fies ~ pangsa_pangan + log(KAPITA) + factor(R105) + factor(tahun), data = df_pangsa_fies)
summary(model_engel)
