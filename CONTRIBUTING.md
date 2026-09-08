# Panduan Kolaborasi & Kontribusi Repositori (Team Onboarding Guide)

Selamat datang di proyek **SUSENAS Research & Data Visualization Framework (Jawa Barat 2019–2023)**!  
Panduan ini dirancang untuk membantu rekan tim dan kolaborator baru dalam menyiapkan lingkungan kerja lokal, memahami arsitektur sistem, serta berkontribusi secara efisien dan terstandarisasi.

---

## 1. Persyaratan Sistem (*Prerequisites*)

Sebelum memulai, pastikan komputer Anda telah terpasang:
- **R (Versi $\ge 4.2.0$):** [Unduh R](https://cran.r-project.org/)
- **RStudio Desktop (Disarankan):** [Unduh RStudio](https://posit.co/download/rstudio-desktop/)  
  *(Atau VS Code dengan ekstensi *R* dan *R Debugger*)*
- **Git:** [Unduh Git](https://git-scm.com/)
- **Quarto CLI (Opsional):** Diperlukan jika ingin mengompilasi dokumen laporan ilmiah (`.qmd`) ke HTML/PDF ([Unduh Quarto](https://quarto.org/docs/get-started/)).

---

## 2. Langkah Onboarding Cepat (Hanya 3 Langkah)

### Langkah 1: Kloning Repositori
Buka terminal (Git Bash, PowerShell, atau Zsh), lalu jalankan:
```bash
git clone https://github.com/Emanxaa/susenas-datviz.git
cd susenas-datviz
```

### Langkah 2: Buka Proyek di RStudio
Klik ganda pada berkas [`susenas-datviz.Rproj`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/susenas-datviz.Rproj).  
RStudio akan secara otomatis menetapkan direktori kerja (*working directory*) ke root repositori, mengaktifkan pengkodean UTF-8, dan memuat indeks proyek.

### Langkah 3: Jalankan Skrip Bootstrap Otomatis
Di R Console (atau jalankan via terminal), cukup ketik perintah:
```r
source("init.R")
```
Skrip [`init.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/init.R) akan secara otomatis:
1. Memeriksa versi R Anda.
2. Mengunduh dan menginstal seluruh package dependensi yang belum ada (`DBI`, `RSQLite`, `tidyverse`, `readxl`, `data.table`, `ggplot2`, `scales`, dll.).
3. Menyiapkan struktur folder yang diperlukan (`database/`, `output/`, `quarto/`, `export_script_r/`).
4. Memeriksa ketersediaan basis data [database/metadata.db](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/database/metadata.db) dan [database/susenas.db](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/database/susenas.db).
5. Memvalidasi modul utilitas [`R/utils.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/R/utils.R).

---

## 3. Kebijakan & Manajemen Data Survei

Sesuai dengan konvensi riset dan keamanan data:
1. **Berkas CSV mentah dan database biner SQLite (`*.db`) TIDAK di-commit ke Git.**  
   Berkas-berkas tersebut berukuran ratusan megabyte hingga gigabyte dan telah diamankan melalui [`.gitignore`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/.gitignore).
2. **Sumber Data Resmi (Google Drive):**  
   Data mentah SUSENAS Jawa Barat (2019–2023) tersimpan pada Google Drive resmi tim:
   - Tautan Root Resmi: [Google Drive SUSENAS Jawa Barat](https://drive.google.com/drive/folders/1oHeu5Hvv4xsnwQtmezc8llA0DlaVhmb-)
   - Tautan Alternatif: [Google Drive Cadangan](https://drive.google.com/drive/folders/12-1KFoASSRUt8yBPUtLX87B_8VAIu6Qx)
3. **Penempatan Berkas Data Mentah:**  
   Jika Anda mengunduh berkas mentah per tahun, tempatkan ke dalam struktur:
   ```text
   SUSENAS/
   └── JAWA BARAT/
       ├── 2023/
       │   ├── csv/
       │   │   ├── KOR/          # Berkas CSV Rumah Tangga & Individu
       │   │   └── Modul KP/     # Berkas CSV BP 4.1, BP 4.2, BP 4.3
       │   └── Metadata dan Kuisioner/
       │       └── Layout_data_Susenas.xlsx
   ```
4. **Membangun Basis Data SQLite Lokal:**  
   Jika berkas `database/susenas.db` belum ada di laptop Anda, jalankan pipeline ETL lokal:
   ```r
   source("R/00_setup.R")          # Inisialisasi skema tabel & indeks
   source("R/01_build_catalog.R")  # Pindai berkas survei
   source("R/02_build_registry.R") # Bangun kamus variabel & label nilai
   source("R/03_import_sqlite.R")  # Impor CSV ke susenas.db & buat analytical views
   source("R/04_build_semantic_registry.R") # Bangun ontologi konsep semantik
   ```

---

## 4. Standar Kode & Konvensi Rekayasa Tim (*Engineering Rules*)

Agar kode yang dibuat oleh rekan tim tetap seragam, cepat, dan kompatibel antar-lingkungan (Windows, macOS, Linux, Google Colab):

### A. Teknologi yang Diizinkan (*Allowed Stack*)
- **HANYA GUNAKAN:** **R**, **SQLite**, **DBI**, **RSQLite**, **tidyverse**, **ggplot2**, **Quarto**.
- **JANGAN GUNAKAN:** Python, DuckDB, Pandas, Spark, Polars. Seluruh pipeline harus dapat dijalankan langsung di sesi R.

### B. Filosofi *SQLite-First* (Wajib Diikuti)
- **DILARANG** membaca seluruh berkas CSV mentah jutaan baris (seperti `kp_bp41` >1,4 juta baris) langsung ke memori R menggunakan `read.csv()` atau `readr::read_csv()`. Tindakan ini akan menghabiskan RAM laptop Anda.
- **Lakukan *Heavy Lifting* di SQLite:** Tulis kueri SQL untuk melakukan filter baris (`WHERE`), join relasi (`INNER JOIN`), dan agregasi grup (`GROUP BY`) di mesin SQLite. Tarik data ke memori R hanya ketika jumlah baris sudah teragregasi ringkas (<1.000 baris).

### C. Pembobotan Sampling BPS (*Survey Weighting*)
- Seluruh estimasi parameter populasi (rerata pengeluaran, asupan nutrisi, proporsi penduduk) **WAJIB** dikalikan dengan faktor penimbang sampling BPS (`WERT` / `PENIMBANG_RT`):
  ```sql
  -- Formula Rata-rata Tertimbang di SQL:
  SUM(PENGELUARAN_PERKAPITA * PENIMBANG_RT) / SUM(PENIMBANG_RT) AS avg_pengeluaran_terbobot
  ```

### D. Kontrak Lingkungan Universal (*Environment-Aware Contract*)
- Setiap skrip yang Anda buat harus dapat dijalankan di RStudio lokal maupun di Google Colab tanpa pengubahan path secara manual.
- **Aturan Wajib:**
  1. Gunakan satu variabel `ROOT_DIR` di awal skrip.
  2. Bangun seluruh path berkas menggunakan fungsi bawaan `file.path(ROOT_DIR, ...)`.
  3. **JANGAN PERNAH** menuliskan path absolut lokal (seperti `D:\IPB\KULIAH\...` atau `C:\Users\...`).
  4. Seluruh koneksi basis data wajib memanggil fungsi pembungkus di [`R/utils.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/R/utils.R): `get_susenas_con()` dan `get_metadata_con()`.

### E. Pantangan Halusinasi Kode Variabel
- Jangan mengarang atau menebak kode variabel.
- Sebelum menulis kueri, periksa kamus resmi menggunakan fungsi pencarian instan di `R/utils.R`:
  ```r
  source("R/utils.R")
  lookup_variable("beras")    # Cari variabel
  lookup_labels("R612")       # Cek label kategori pendidikan
  get_join_keys("kor_rt", "kor_individu") # Cek kunci join resmi
  ```
- Rujuk dokumen lengkap: [`REKOMENDASI_VARIABEL_RAWAN_PANGAN.md`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/REKOMENDASI_VARIABEL_RAWAN_PANGAN.md) dan [`SQL.md`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/SQL.md).

---

## 5. Katalog Skrip & Template yang Siap Digunakan

Rekan tim dapat langsung memanfaatkan skrip dan template analitis siap pakai berikut:

| Skrip | Fungsi & Tujuan Riset | Contoh Perintah Terminal |
| :--- | :--- | :--- |
| [`universal_pipeline.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/universal_pipeline.R) | Pipeline analitis universal environment-aware (RStudio & Google Colab) | `Rscript universal_pipeline.R` |
| [`export_script_r/export_rawan_pangan_2023.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/export_script_r/export_rawan_pangan_2023.R) | Pemetaan 27 Kabupaten/Kota rawan pangan, FIES, defisit kalori, dan bansos | `Rscript export_script_r/export_rawan_pangan_2023.R` |
| [`export_script_r/export_script_r.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/export_script_r/export_script_r.R) | Uji empiris Hukum Engel (pangsa pangan vs pendidikan KRT) | `Rscript export_script_r/export_script_r.R` |
| [`R/semantic_planner.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/R/semantic_planner.R) | Generator analisis otomatis dari bahasa alami (`plan_susenas()`) | Dipanggil di sesi R |
| `R/*_template.R` | 7 template analisis modular (Barplot, Boxplot, Histogram, Crosstab, Proporsi, Tren, Frekuensi) | Dipanggil via `source()` |

---

## 6. Alur Kerja Git & Kontribusi (*Git Collaboration Workflow*)

1. **Sinkronisasi Kode Terbaru:**
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Buat Branch Baru untuk Analisis Anda:**
   Gunakan format penamaan branch yang jelas:
   - `feature/nama-analisis` (misal: `feature/stunting-kemiskinan`)
   - `fix/nama-perbaikan` (misal: `fix/label-pendidikan`)
   ```bash
   git checkout -b feature/analisis-kemiskinan-pkh
   ```
3. **Kembangkan Kode & Uji Coba:**
   Pastikan skrip Anda dapat dieksekusi tanpa peringatan (*warning*) atau kegagalan koneksi.
4. **Commit Perubahan:**
   Tulis pesan commit yang deskriptif dan terstruktur:
   ```bash
   git add R/analisis_baru.R
   git commit -m "feat: tambahkan analisis disparitas kemiskinan dan penerima PKH 2023"
   ```
5. **Kirim ke Remote Repository & Buat Pull Request (PR):**
   ```bash
   git push origin feature/analisis-kemiskinan-pkh
   ```
   Buka GitHub dan ajukan *Pull Request* ke branch `main` untuk direview oleh rekan tim.

---

Jika ada pertanyaan atau kendala dalam bootstrap proyek, hubungi pemilik repositori atau buat isu baru di tab *Issues* GitHub! Selamat meneliti! 🚀
