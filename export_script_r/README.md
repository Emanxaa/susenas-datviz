# Direktori Ekspor Skrip & Data: `export_script_r/`

Folder ini menampung seluruh skrip otomasi analitis dan berkas hasil ekspor data riset SUSENAS Jawa Barat 2023.

---

## 1. Daftar Skrip Analitis yang Tersedia

### A. [`export_rawan_pangan_2023.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/export_script_r/export_rawan_pangan_2023.R)
- **Topik:** **Identifikasi Daerah Rawan Pangan Provinsi Jawa Barat 2023**
- **Cakupan Wilayah:** 27 Kabupaten/Kota dan Klasifikasi Perkotaan/Perdesaan.
- **Indikator Multidimensi:**
  1. *Dimensi Beban Pengeluaran Pangan:* Pangsa Pengeluaran Makanan (Hukum Engel) & Persentase RT dengan pangsa $>60\%$.
  2. *Dimensi Pemanfaatan Gizi Makro:* Defisit Energi Kalori ($<2.100$ Kkal) dan Defisit Protein ($<57$ Gram).
  3. *Dimensi Pengalaman Kerawanan Pangan Subjektif:* 8 Pertanyaan Standar FAO/BPS *Food Insecurity Experience Scale* (FIES: `R1701`–`R1708`).
  4. *Dimensi Jaring Pengaman Sosial:* Cakupan Bantuan Pangan Non-Tunai (BPNT `R2207`) dan PKH (`R2204A`).
  5. *Indeks Komposit Kerawanan Pangan:* Skor terstandarisasi (0–100) untuk menetapkan 4 klaster prioritas intervensi.
- **Berkas Output:**
  - `tabel_rawan_pangan_kabkot.csv`
  - `tabel_rawan_pangan_desa_kota.csv`
  - `grafik_ranking_rawan_pangan.png` (300 DPI)
  - `grafik_matriks_rawan_pangan.png` (300 DPI)
  - `grafik_disparitas_desa_kota.png` (300 DPI)
  - `hasil_rawan_pangan_lengkap.rds`

---

### B. [`export_script_r.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/export_script_r/export_script_r.R)
- **Topik:** **Analisis Ketahanan Pangan Berdasarkan Pendidikan KRT Jawa Barat 2023**
- **Fokus:** Uji empiris Hukum Engel (penurunan pangsa pangan terhadap peningkatan jenjang pendidikan KRT) dan perbandingan asupan gizi makro.
- **Berkas Output:**
  - `tabel_ketahanan_pangan_kebijakan.csv`
  - `tabel_ketahanan_pangan_rinci.csv`
  - `ringkasan_indikator_jabar.csv`
  - `grafik_pangsa_pangan_pendidikan.png` (300 DPI)
  - `grafik_kecukupan_gizi_pendidikan.png` (300 DPI)
  - `hasil_analisis_lengkap.rds`

---

## 2. Cara Menjalankan Skrip

Skrip dirancang *environment-aware* (berjalan mulus di **RStudio Project** maupun **Google Colab** tanpa modifikasi):

```bash
# Menjalankan pemetaan daerah rawan pangan Jawa Barat 2023
Rscript export_script_r/export_rawan_pangan_2023.R

# Menjalankan analisis ketahanan pangan menurut pendidikan KRT
Rscript export_script_r/export_script_r.R
```
