# Test simple digital lifestyle analysis on 2023 KOR INDIVIDU PART1
library(dplyr)

root_data <- if (dir.exists(file.path("SUSENAS", "JAWA BARAT"))) file.path("SUSENAS", "JAWA BARAT") else "JAWA BARAT"
f <- file.path(root_data, "2023", "csv", "KOR", "2023 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv")

data <- read.csv(f, stringsAsFactors = FALSE)
cat("Total baris individu 2023:", nrow(data), "\n")

# Filter usia 5 tahun ke atas (karena blok TIK hanya untuk usia >= 5 tahun)
data_tik <- data[data$R407 >= 5, ]
cat("Total individu usia >= 5 tahun:", nrow(data_tik), "\n")

# Topik 1: Punya HP (R802 == 1) & Akses Internet (R808 == 1)
prop_hp <- mean(data_tik$R802 == 1, na.rm = TRUE) * 100
prop_net <- mean(data_tik$R808 == 1, na.rm = TRUE) * 100
cat(sprintf("Proporsi Punya HP: %.2f%%\n", prop_hp))
cat(sprintf("Proporsi Akses Internet: %.2f%%\n", prop_net))

# Topik 2: Kota vs Desa
t_desa_kota <- tapply(data_tik$R808 == 1, data_tik$R105, function(x) mean(x, na.rm = TRUE) * 100)
cat("\nAkses Internet Kota (1) vs Desa (2):\n")
print(round(t_desa_kota, 2))

# Topik 3: Antar Generasi
data_tik$generasi <- ifelse(data_tik$R407 <= 24, "Gen Z & Anak (5-24)",
                     ifelse(data_tik$R407 <= 59, "Dewasa/Produktif (25-59)", "Lansia (60+)"))
t_gen <- tapply(data_tik$R808 == 1, data_tik$generasi, function(x) mean(x, na.rm = TRUE) * 100)
cat("\nAkses Internet Antar Generasi:\n")
print(round(t_gen, 2))
