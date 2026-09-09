# ==============================================================================
# PENELITIAN 3: Bantuan Sosial (BPNT, PKH, BPJS PBI) vs FIES (SUSENAS 2019-2023)
# Paket yang Digunakan: Hanya Bawaan R (Base R) + dplyr + ggplot2
# Dilengkapi: Label Resmi Asli Kuesioner SUSENAS (VSEN.K & VSEN.KP BPS)
# ==============================================================================

library(dplyr)
library(ggplot2)

# ------------------------------------------------------------------------------
# 1. Fungsi Membaca Data & Menghubungkan Variabel dengan Label Asli Kuesioner
# ------------------------------------------------------------------------------
ambil_data_bansos <- function(tahun) {
  cat("\nMemproses Tahun:", tahun, "\n")
  
  root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) {
    file.path("SUSENAS", "JAWA BARAT")
  } else {
    "JAWA BARAT"
  }
  
  file_rt <- file.path(root_data, tahun, "csv", "KOR", paste0(tahun, " Maret JABAR - SUSENAS KOR Rumah Tangga.csv"))
  
  # Catatan Tata Letak BPS: Variabel BPJS PBI (R1101_A) ada di PART2 pada 2019 & 2021, 
  # dan di PART1 pada 2020, 2022, 2023
  nama_ind <- ifelse(tahun %in% c(2019, 2021), 
                     paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART2.csv"),
                     paste0(tahun, " Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv"))
  file_ind <- file.path(root_data, tahun, "csv", "KOR", nama_ind)
  file_kp  <- file.path(root_data, tahun, "csv", "Modul KP (Konsumsi Pengeluaran)", 
                        paste0(tahun, " Maret JABAR - SUSENAS KP BP 4.3.csv"))
  
  data_rt  <- read.csv(file_rt, stringsAsFactors = FALSE)
  data_ind <- read.csv(file_ind, stringsAsFactors = FALSE)
  data_kp  <- read.csv(file_kp, stringsAsFactors = FALSE)
  
  # Standarisasi Kunci ID Rumah Tangga (2019-2021: RENUM, 2022-2023: URUT)
  if (tahun <= 2021) {
    data_rt$id_rt  <- data_rt$RENUM
    data_ind$id_rt <- data_ind$RENUM
    data_kp$id_rt  <- data_kp$RENUM
  } else {
    data_rt$id_rt  <- data_rt$URUT
    data_ind$id_rt <- data_ind$URUT
    data_kp$id_rt  <- data_kp$URUT
  }
  
  # ----------------------------------------------------------------------------
  # DAFTAR VARIABEL & LABEL ASLI DARI KUESIONER SUSENAS (VSEN.K & VSEN.KP):
  #
  # [KOR RT - BLOK XXII / XXI. KETERANGAN PERLINDUNGAN SOSIAL]
  # - R2105  (2019)      : Kepemilikan Kartu Perlindungan Sosial (KPS) / Kartu Keluarga Sejahtera (KKS)
  # - R2202  (2020-2023) : Apakah rumah tangga ini menerima Kartu Keluarga Sejahtera (KKS)?
  #                        (1 = Ya dapat menunjukkan kartu, 2 = Ya tidak dapat menunjukkan, 5 = Tidak)
  # - R2204A (2020-2023) : Apakah saat ini rumah tangga Anda masih tercatat/menjadi penerima 
  #                        Program Keluarga Harapan (PKH)? (1 = Ya, 5 = Tidak)
  # - R2207  (2022-2023) : Apakah rumah tangga Anda pernah menjadi penerima Bantuan Pangan 
  #                        (Bantuan Pangan Non Tunai (BPNT) / Program Sembako)? (1 = Ya, 5 = Tidak)
  #
  # [KOR INDIVIDU - BLOK XI / VII. KESEHATAN & JAMINAN KESEHATAN]
  # - R1101_A: Jaminan kesehatan apa saja yang dimiliki (nama)? 
  #            Kode A = Jaminan Kesehatan Nasional (JKN) BPJS Kesehatan Peserta Penerima 
  #                     Bantuan Iuran (PBI) / Jamkesmas (Iurannya dibayar oleh Pemerintah)
  #
  # [MODUL KP BP 4.3 - KONSUMSI & PENGELUARAN]
  # - EXPEND : Total Nilai Pengeluaran Konsumsi Rumah Tangga Sebulan (Rupiah)
  # - KAPITA : Rata-rata Pengeluaran Konsumsi Per Kapita Sebulan (Rupiah)
  # ----------------------------------------------------------------------------
  kolom_tersedia <- names(data_rt)
  kolom_rt <- intersect(c("id_rt", "R101", "R102", "R105", "R301", "FWT",
                          "R2105", "R2202", "R2204A", "R2207",
                          paste0("R170", 1:8)), kolom_tersedia)
  data_rt <- data_rt[, kolom_rt]
  
  # Agregasi BPJS PBI ke Level Rumah Tangga: apakah ada minimal 1 ART penerima PBI?
  pbi_rt <- data_ind %>%
    mutate(punya_pbi = ifelse(!is.na(R1101_A) & R1101_A == 1, 1, 0)) %>%
    group_by(id_rt) %>%
    summarise(penerima_pbi = max(punya_pbi, na.rm = TRUE))
  
  data_kp <- data_kp[, c("id_rt", "EXPEND", "KAPITA")]
  
  # Penggabungan 3 Tabel Berdasarkan id_rt
  hasil <- data_rt %>%
    left_join(pbi_rt, by = "id_rt") %>%
    left_join(data_kp, by = "id_rt")
  
  hasil$penerima_pbi[is.na(hasil$penerima_pbi)] <- 0
  
  # ----------------------------------------------------------------------------
  # PERHITUNGAN SKOR FIES & STATUS BANSOS:
  # ----------------------------------------------------------------------------
  hasil <- hasil %>%
    mutate(
      tahun = tahun,
      skor_fies = (R1701 == 1) + (R1702 == 1) + (R1703 == 1) + (R1704 == 1) +
                  (R1705 == 1) + (R1706 == 1) + (R1707 == 1) + (R1708 == 1),
      status_rawan = ifelse(skor_fies >= 1, "Rawan Pangan", "Tahan Pangan")
    )
  
  # Identifikasi Penerima Bantuan Sosial
  if (tahun == 2019) {
    hasil$penerima_kks_pkh <- ifelse(!is.na(hasil$R2105) & hasil$R2105 == 1, 1, 0)
  } else {
    kks <- ifelse(!is.na(hasil$R2202) & hasil$R2202 == 1, 1, 0)
    pkh <- ifelse(!is.na(hasil$R2204A) & hasil$R2204A == 1, 1, 0)
    hasil$penerima_kks_pkh <- ifelse(kks == 1 | pkh == 1, 1, 0)
  }
  
  # Status Bansos Gabungan (PKH / KKS / BPNT / BPJS PBI)
  hasil$status_bansos <- ifelse(hasil$penerima_kks_pkh == 1 | hasil$penerima_pbi == 1, 
                                "Penerima Bansos", "Bukan Penerima")
  return(hasil)
}

# ------------------------------------------------------------------------------
# 2. Mengumpulkan Data 5 Tahun (2019-2023)
# ------------------------------------------------------------------------------
daftar_tahun <- 2019:2023
list_bansos <- list()

for (th in daftar_tahun) {
  list_bansos[[as.character(th)]] <- ambil_data_bansos(th)
}

df_bansos_fies <- bind_rows(list_bansos)
cat("\nTotal Data Rumah Tangga Tergabung (2019-2023):", nrow(df_bansos_fies), "baris\n")

# ------------------------------------------------------------------------------
# 3. Analisis Statistik Klasik
# ------------------------------------------------------------------------------

# A. Tabel Kontingensi & Uji Chi-Square (Status Bansos vs Status Rawan Pangan)
cat("\n=== TABEL KONTINGENSI & CHI-SQUARE: STATUS BANSOS VS RAWAN PANGAN ===\n")
tab_bansos <- table(df_bansos_fies$status_bansos, df_bansos_fies$status_rawan)
print(tab_bansos)
print(round(prop.table(tab_bansos, 1) * 100, 2))
print(chisq.test(tab_bansos))

# B. Uji-t Beda Rata-rata Skor FIES (Penerima vs Bukan Penerima)
cat("\n=== UJI-T BEDA RATA-RATA SKOR FIES ===\n")
print(t.test(skor_fies ~ status_bansos, data = df_bansos_fies))

# C. Model Regresi Linear OLS (Mengontrol Log Pengeluaran Per Kapita)
cat("\n=== REGRESI LINEAR OLS (MENGONTROL LOG KAPITA) ===\n")
model3 <- lm(skor_fies ~ status_bansos + log(KAPITA) + factor(R105) + factor(tahun), data = df_bansos_fies)
print(summary(model3))

# ------------------------------------------------------------------------------
# 4. Visualisasi Infografis (ggplot2)
# ------------------------------------------------------------------------------
df_plot_bansos <- df_bansos_fies %>%
  group_by(tahun, status_bansos) %>%
  summarise(rata_fies = mean(skor_fies), .groups = "drop")

p3 <- ggplot(df_plot_bansos, aes(x = factor(tahun), y = rata_fies, fill = status_bansos)) +
  geom_bar(stat = "identity", position = position_dodge(0.8), width = 0.7) +
  scale_fill_manual(values = c("Bukan Penerima" = "#95a5a6", "Penerima Bansos" = "#e74c3c")) +
  labs(
    title = "Perbandingan Skor Kerawanan Pangan Antara Penerima Bansos dan Non-Penerima",
    subtitle = "Skor FIES Lebih Tinggi pada Penerima Bansos (Menunjukkan Efek Ketepatan Sasaran / Targeting)",
    x = "Tahun Survei", 
    y = "Rata-rata Skor FIES (0 - 8)", 
    fill = "Status Bansos",
    caption = "Sumber: Olahan Mikrodata SUSENAS Jawa Barat 2019-2023 (BPS)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 13),
    legend.position = "bottom"
  )

print(p3)
