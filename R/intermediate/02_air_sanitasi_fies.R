# ==============================================================================
# PENELITIAN 2: Air Bersih, Sanitasi, dan Kerawanan Pangan (SUSENAS 2019-2023)
# Tingkat Kesulitan: Intermediate (Mudah Dipahami & Dijalankan Baris demi Baris)
# ==============================================================================

library(data.table)
library(dplyr)

ambil_data_sanitasi <- function(tahun) {
  message(paste(">> Memproses Tahun:", tahun))
  
  id_col <- ifelse(tahun <= 2021, "RENUM", "URUT")
  
  file_rt <- file.path("SUSENAS", "JAWA BARAT", tahun, "csv", "KOR", 
                       paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  
  # Ambil variabel air minum (R1810A), tempat BAB (R1809A), kloset (R1809B), tinja (R1809C)
  kolom_rt <- c(id_col, "R101", "R102", "R105", "FWT",
                "R1810A", "R1809A", "R1809B", "R1809C",
                "R1701", "R1702", "R1703", "R1704", "R1705", "R1706", "R1707", "R1708")
  
  dt <- fread(file_rt, select = kolom_rt)
  
  hasil <- dt %>%
    rename(id_rt = all_of(id_col)) %>%
    mutate(
      tahun = tahun,
      # Skor FIES
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan", "Tahan Pangan"),
      
      # Kriteria BPS: Air Minum Layak (leding, sumur bor/terlindung, mata air terlindung)
      air_layak = ifelse(R1810A %in% c(1, 2, 3, 4, 6, 7), "Layak", "Tidak Layak"),
      
      # Kriteria BPS: Sanitasi Layak (jamban sendiri, leher angsa, tangki septik)
      sanitasi_layak = ifelse(R1809A %in% c(1, 2) & R1809B == 1 & R1809C == 1, "Layak", "Tidak Layak"),
      
      # Kombinasi untuk Heatmap
      kombinasi_wash = case_when(
        air_layak == "Layak" & sanitasi_layak == "Layak" ~ "Air & Sanitasi Layak",
        air_layak == "Layak" & sanitasi_layak == "Tidak Layak" ~ "Hanya Air Layak",
        air_layak == "Tidak Layak" & sanitasi_layak == "Layak" ~ "Hanya Sanitasi Layak",
        TRUE ~ "Keduanya Tidak Layak"
      )
    )
  
  return(hasil)
}

daftar_tahun <- 2019:2023
list_wash <- list()
for (th in daftar_tahun) {
  list_wash[[as.character(th)]] <- ambil_data_sanitasi(th)
}
df_wash_fies <- bind_rows(list_wash)

# Analisis Statistik Klasik
message("
--- TABEL KONTINGENSI: SANITASI VS KERAWANAN PANGAN ---")
tabel_sanitasi <- table(df_wash_fies$sanitasi_layak, df_wash_fies$status_rawan)
print(tabel_sanitasi)

message("
--- UJI CHI-SQUARE (SANITASI VS FIES) ---")
uji_chi_sanitasi <- chisq.test(tabel_sanitasi)
print(uji_chi_sanitasi)

message("
--- TABEL KONTINGENSI: AIR MINUM VS KERAWANAN PANGAN ---")
tabel_air <- table(df_wash_fies$air_layak, df_wash_fies$status_rawan)
print(tabel_air)

message("
--- UJI CHI-SQUARE (AIR MINUM VS FIES) ---")
uji_chi_air <- chisq.test(tabel_air)
print(uji_chi_air)
