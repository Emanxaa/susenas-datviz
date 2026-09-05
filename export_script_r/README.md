# Folder Ekspor Hasil Analisis: `export_script_r/`

Folder ini menampung seluruh skrip otomasi dan berkas hasil ekspor data analitis dari permintaan riset SUSENAS Jawa Barat 2023.

---

## 1. Skrip Utama
- [`export_script_r.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/export_script_r/export_script_r.R): Skrip R mandiri (*self-contained*) yang mengeksekusi pipeline end-to-end:
  1. Koneksi ke `database/susenas.db` dan `database/metadata.db`.
  2. Kueri SQL terbobot (`WERT`) langsung di mesin SQLite (*heavy lifting*).
  3. Pelabelan kategori resmi dari `value_labels`.
  4. Perhitungan pangsa pengeluaran pangan (Hukum Engel) dan kecukupan nutrisi (Kalori & Protein vs WNPG).
  5. Pembuatan grafik visualisasi `ggplot2` standar publikasi.
  6. Ekspor seluruh tabel, grafik, dan objek data ke folder ini.

---

## 2. Berkas Hasil yang Dihasilkan
Ketika skrip dijalankan, berkas-berkas berikut akan otomatis terbentuk di folder ini:

| Nama Berkas | Tipe | Deskripsi Isi |
| :--- | :--- | :--- |
| `tabel_ketahanan_pangan_kebijakan.csv` | CSV | Ringkasan 5 kategori pendidikan KRT (sampel, estimasi populasi RT, pengeluaran pangan, total pengeluaran, pangsa pangan %, kalori/kapita/hari, protein/kapita/hari). |
| `tabel_ketahanan_pangan_rinci.csv` | CSV | Rincian 24 jenjang pendidikan resmi kuesioner BPS (`R612`). |
| `ringkasan_indikator_jabar.csv` | CSV | Angka patokan (*benchmark*) agregat total Provinsi Jawa Barat. |
| `grafik_pangsa_pangan_pendidikan.png` | Gambar (300 DPI) | Bar chart pangsa pengeluaran makanan (bukti Hukum Engel) menurut pendidikan KRT. |
| `grafik_kecukupan_gizi_pendidikan.png` | Gambar (300 DPI) | Visualisasi komparasi konsumsi kalori & protein terhadap standar baku kecukupan gizi WNPG (2.100 Kkal & 57 Gram). |
| `hasil_analisis_lengkap.rds` | RDS R Data | Bundle data R berisi seluruh tabel dan objek plot ggplot2 untuk analisis lanjutan atau pelaporan Quarto. |

---

## 3. Cara Menjalankan Ulang
Untuk menjalankan ulang seluruh ekspor kapan saja, cukup jalankan perintah berikut di terminal:

```bash
Rscript export_script_r/export_script_r.R
```
atau dari root direktori:
```bash
Rscript export_script_r.R
```
