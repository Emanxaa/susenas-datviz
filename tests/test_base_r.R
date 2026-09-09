# Comprehensive verification of all 4 RQs using Intermediate Base R syntax

root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) file.path("SUSENAS", "JAWA BARAT") else "JAWA BARAT"

# ==============================================================================
# RQ 1: BALITA & FIES
# ==============================================================================
ambil_data_balita <- function(tahun) {
  cat("Memproses RQ1 Tahun:", tahun, "\n")
  if (tahun <= 2021) { id_col <- "RENUM" } else { id_col <- "URUT" }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  file_ind <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv"))
  
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  kolom_rt <- c(id_col, "R101", "R102", "R105", "R301", "FWT", paste0("R170", 1:8))
  data_rt <- data_rt[, kolom_rt]
  
  data_ind <- read.csv(file_ind, stringsAsFactors = FALSE)
  kolom_ind <- c(id_col, "R407")
  data_ind <- data_ind[, kolom_ind]
  
  data_ind$is_balita <- ifelse(data_ind$R407 < 5, 1, 0)
  balita_rt <- aggregate(data_ind$is_balita, by = list(data_ind[[id_col]]), FUN = sum, na.rm = TRUE)
  colnames(balita_rt) <- c(id_col, "jumlah_balita")
  
  hasil <- merge(data_rt, balita_rt, by = id_col, all.x = TRUE)
  hasil$jumlah_balita[is.na(hasil$jumlah_balita)] <- 0
  hasil$id_rt <- hasil[[id_col]]
  hasil[[id_col]] <- NULL
  hasil$tahun <- tahun
  
  hasil$skor_fies <- (hasil$R1701 == 1) + (hasil$R1702 == 1) + (hasil$R1703 == 1) + (hasil$R1704 == 1) +
                     (hasil$R1705 == 1) + (hasil$R1706 == 1) + (hasil$R1707 == 1) + (hasil$R1708 == 1)
  
  hasil$kategori_balita <- ifelse(hasil$jumlah_balita == 0, "0 Balita",
                           ifelse(hasil$jumlah_balita == 1, "1 Balita",
                           ifelse(hasil$jumlah_balita == 2, "2 Balita", "3+ Balita")))
  return(hasil)
}

# ==============================================================================
# RQ 2: WASH & FIES
# ==============================================================================
ambil_data_wash <- function(tahun) {
  cat("Memproses RQ2 Tahun:", tahun, "\n")
  if (tahun <= 2021) { id_col <- "RENUM" } else { id_col <- "URUT" }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  
  kolom_rt <- c(id_col, "R101", "R102", "R105", "R301", "FWT",
                "R1810A", "R1809A", "R1809B", "R1809C", paste0("R170", 1:8))
  data_rt <- data_rt[, kolom_rt]
  
  data_rt$id_rt <- data_rt[[id_col]]
  data_rt[[id_col]] <- NULL
  data_rt$tahun <- tahun
  
  data_rt$skor_fies <- (data_rt$R1701 == 1) + (data_rt$R1702 == 1) + (data_rt$R1703 == 1) + (data_rt$R1704 == 1) +
                       (data_rt$R1705 == 1) + (data_rt$R1706 == 1) + (data_rt$R1707 == 1) + (data_rt$R1708 == 1)
  data_rt$status_rawan <- ifelse(data_rt$skor_fies >= 1, "Rawan Pangan", "Tahan Pangan")
  
  data_rt$air_layak <- ifelse(data_rt$R1810A %in% c(1, 2, 3, 4, 6, 7), "Air Layak", "Air Tidak Layak")
  data_rt$sanitasi_layak <- ifelse(data_rt$R1809A %in% c(1, 2) & data_rt$R1809B == 1 & data_rt$R1809C == 1,
                                   "Sanitasi Layak", "Sanitasi Tidak Layak")
  
  data_rt$kombinasi_wash <- ifelse(data_rt$air_layak == "Air Layak" & data_rt$sanitasi_layak == "Sanitasi Layak", "Air & Sanitasi Layak",
                            ifelse(data_rt$air_layak == "Air Layak" & data_rt$sanitasi_layak != "Sanitasi Layak", "Hanya Air Layak",
                            ifelse(data_rt$air_layak != "Air Layak" & data_rt$sanitasi_layak == "Sanitasi Layak", "Hanya Sanitasi Layak",
                                   "Keduanya Tidak Layak")))
  return(data_rt)
}

# ==============================================================================
# RQ 3: BANSOS & FIES
# ==============================================================================
ambil_data_bansos <- function(tahun) {
  cat("Memproses RQ3 Tahun:", tahun, "\n")
  if (tahun <= 2021) { id_col <- "RENUM" } else { id_col <- "URUT" }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  nama_ind <- ifelse(tahun %in% c(2019, 2021), 
                     paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART2.csv"),
                     paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv"))
  file_ind <- file.path(root_data, tahun, "csv", "KOR", nama_ind)
  file_kp <- file.path(root_data, tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  kolom_tersedia_rt <- names(data_rt)
  kolom_pilihan_rt <- intersect(c(id_col, "R101", "R102", "R105", "R301", "FWT",
                                  "R2105", "R2202", "R2204A", "R2207", paste0("R170", 1:8)), kolom_tersedia_rt)
  data_rt <- data_rt[, kolom_pilihan_rt]
  
  data_ind <- read.csv(file_ind, stringsAsFactors = FALSE)
  kolom_ind <- c(id_col, "R1101_A")
  data_ind <- data_ind[, kolom_ind]
  data_ind$punya_pbi <- ifelse(!is.na(data_ind$R1101_A) & data_ind$R1101_A == 1, 1, 0)
  pbi_rt <- aggregate(data_ind$punya_pbi, by = list(data_ind[[id_col]]), FUN = max, na.rm = TRUE)
  colnames(pbi_rt) <- c(id_col, "penerima_pbi")
  
  data_kp <- read.csv(file_kp, stringsAsFactors = FALSE)
  data_kp <- data_kp[, c(id_col, "EXPEND", "KAPITA")]
  
  hasil <- merge(data_rt, pbi_rt, by = id_col, all.x = TRUE)
  hasil <- merge(hasil, data_kp, by = id_col, all.x = TRUE)
  hasil$penerima_pbi[is.na(hasil$penerima_pbi)] <- 0
  
  hasil$id_rt <- hasil[[id_col]]
  hasil[[id_col]] <- NULL
  hasil$tahun <- tahun
  
  hasil$skor_fies <- (hasil$R1701 == 1) + (hasil$R1702 == 1) + (hasil$R1703 == 1) + (hasil$R1704 == 1) +
                     (hasil$R1705 == 1) + (hasil$R1706 == 1) + (hasil$R1707 == 1) + (hasil$R1708 == 1)
  hasil$status_rawan <- ifelse(hasil$skor_fies >= 1, "Rawan Pangan", "Tahan Pangan")
  
  if (tahun == 2019) {
    hasil$penerima_kks_pkh <- ifelse(!is.na(hasil$R2105) & hasil$R2105 == 1, 1, 0)
  } else {
    kks <- ifelse(!is.na(hasil$R2202) & hasil$R2202 == 1, 1, 0)
    pkh <- ifelse(!is.na(hasil$R2204A) & hasil$R2204A == 1, 1, 0)
    hasil$penerima_kks_pkh <- ifelse(kks == 1 | pkh == 1, 1, 0)
  }
  hasil$status_bansos <- ifelse(hasil$penerima_kks_pkh == 1 | hasil$penerima_pbi == 1, "Penerima Bansos", "Bukan Penerima")
  return(hasil)
}

# ==============================================================================
# RQ 4: PANGSA PENGELUARAN PANGAN & FIES
# ==============================================================================
ambil_data_pangsa <- function(tahun) {
  cat("Memproses RQ4 Tahun:", tahun, "\n")
  if (tahun <= 2021) { id_col <- "RENUM" } else { id_col <- "URUT" }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  file_kp <- file.path(root_data, tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  data_rt <- read.csv(file_rt, stringsAsFactors = FALSE)
  kolom_rt <- c(id_col, "R101", "R102", "R105", "R301", "FWT", paste0("R170", 1:8))
  data_rt <- data_rt[, kolom_rt]
  
  data_kp <- read.csv(file_kp, stringsAsFactors = FALSE)
  kolom_kp <- c(id_col, "FOOD", "NONFOOD", "EXPEND", "KAPITA")
  data_kp <- data_kp[, kolom_kp]
  
  hasil <- merge(data_rt, data_kp, by = id_col, all.x = TRUE)
  hasil$id_rt <- hasil[[id_col]]
  hasil[[id_col]] <- NULL
  hasil$tahun <- tahun
  
  hasil$skor_fies <- (hasil$R1701 == 1) + (hasil$R1702 == 1) + (hasil$R1703 == 1) + (hasil$R1704 == 1) +
                     (hasil$R1705 == 1) + (hasil$R1706 == 1) + (hasil$R1707 == 1) + (hasil$R1708 == 1)
  hasil$status_rawan <- ifelse(hasil$skor_fies >= 1, "Rawan Pangan", "Tahan Pangan")
  
  hasil$pangsa_pangan <- (hasil$FOOD / hasil$EXPEND) * 100
  hasil$kategori_engel <- ifelse(hasil$pangsa_pangan >= 60, "PPP >= 60% (Rawan Tinggi)", "PPP < 60% (Tahan Pangan)")
  
  # Filter data valid
  hasil <- hasil[hasil$EXPEND > 0 & !is.na(hasil$pangsa_pangan) & hasil$pangsa_pangan <= 100, ]
  return(hasil)
}

# Test 2023 for all 4
d1 <- ambil_data_balita(2023)
d2 <- ambil_data_wash(2023)
d3 <- ambil_data_bansos(2023)
d4 <- ambil_data_pangsa(2023)

cat("\nSummary 2023:\n")
cat("RQ1 Balita Rows:", nrow(d1), "\n")
cat("RQ2 WASH Rows:", nrow(d2), "\n")
cat("RQ3 Bansos Rows:", nrow(d3), "\n")
cat("RQ4 Pangsa Rows:", nrow(d4), "\n")
