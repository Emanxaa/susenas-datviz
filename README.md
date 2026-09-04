# SUSENAS Research & Data Visualization Framework (Jawa Barat 2019–2023)

Sistem otomasi riset dan visualisasi data survei **SUSENAS BPS Jawa Barat (2019–2023)** berbasis **R**, **SQLite**, dan **tidyverse**. Framework ini dirancang untuk memangkas waktu kerja dari pertanyaan riset menjadi laporan analitis siap publikasi (*Quarto-ready*) tanpa bergantung pada pembacaan file mentah berukuran gigabyte ke dalam memori kerja.

---

## 1. Arsitektur & Filosofi Sistem

1. **Grounded & Anti-Halusinasi:** Tidak ada tebakan variabel atau pengkodean manual. Semua variabel merujuk pada kamus data resmi BPS (*Layout_data_Susenas.xlsx* dan *VSEN.pdf*).
2. **Context- & Token-Efficient:** Menghindari pemuatan seluruh berkas CSV atau PDF ke dalam konteks komputasi. Menggunakan hirarki progressive retrieval:
   $$\text{User Request} \rightarrow \text{metadata.db} \rightarrow \text{SQLite Query} \rightarrow \text{Tidyverse Wrangling} \rightarrow \text{ggplot2}$$
3. **Heavy Lifting in SQLite:** Agregasi berat, filtering, dan join dieksekusi di dalam SQLite sebelum data ditarik ke dalam R.

---

## 2. Struktur Repositori

```text
├── .agentignore              # Mencegah agen AI memuat CSV/PDF mentah ke context
├── .gitignore                # Mengamankan database biner dan raw data dari Git
├── AGENTS.md                 # Konfigurasi sistem dan aturan operasional asisten AI
├── database/
│   ├── metadata.db           # Cache SQLite: katalog survei, kamus variabel, label, join
│   └── susenas.db            # Basis data SQLite analitis untuk tabel/view survei
├── R/
│   ├── utils.R               # Modul fungsi koneksi & pencarian instan (lookup)
│   ├── 00_setup.R            # Bootstrap direktori & inisialisasi skema tabel berindeks
│   ├── 01_build_catalog.R    # Scanner otomatis berkas survei ke survey_catalog
│   └── 02_build_registry.R   # Parser otomatis layout Excel ke variable_registry & value_labels
├── SUSENAS/
│   └── JAWA BARAT/
│       ├── 2019/ (csv, dbf, Metadata dan Kuisioner)
│       ├── 2020/ (csv, dbf, Metadata dan Kuisioner)
│       ├── 2021/ (csv, dbf, Metadata dan Kuisioner)
│       ├── 2022/ (csv, dbf, Metadata dan Kuisioner)
│       └── 2023/ (csv, dbf, Metadata dan Kuisioner)
├── output/                   # Folder penampung grafik ekspor dan hasil komputasi
└── quarto/                   # Folder dokumen reproduktif (.qmd)
```

---

## 3. Fitur yang Sudah Berjalan

### A. Katalogisasi Dataset Multi-Tahun (`survey_catalog`)
* Memetakan seluruh inventori dari Google Drive Root resmi (`1oHeu5Hvv4xsnwQtmezc8llA0DlaVhmb-`).
* **30 berkas CSV** terindeks penuh (6 berkas per tahun untuk 2019–2023):
  * **Modul KOR:** `Rumah Tangga`, `INDIVIDU PART1`, `INDIVIDU PART2`.
  * **Modul KP:** `KP BP 4.1` (Bahan Makanan), `KP BP 4.2` (Bukan Makanan), `KP BP 4.3` (Rekapitulasi).
* Pemetaan berkas instrumen kuesioner dan buku layout per tahun survei.

### B. Kamus Variabel & Pencarian Instan (`variable_registry`)
* Terindeks **557 variabel resmi** yang siap dicari secara instan (<5 ms):
  * `kor_individu`: 283 variabel
  * `kor_rt`: 199 variabel
  * `kp_bp41`: 27 variabel
  * `kp_bp42`: 26 variabel
  * `kp_bp43`: 22 variabel
* Mendukung pencarian berbasis kata kunci parsial (fuzzy/LIKE match) pada nama variabel maupun teks pertanyaan resmi.

### C. Kamus Label Nilai Kategorik (`value_labels`)
* Terindeks **1.964 pasangan nilai dan label kategori** dari 230 variabel berkategori.
* Memungkinkan konversi otomatis dari kode numerik survei (misal: kode provinsi, jenjang pendidikan, jenis lantai, kepemilikan aset) menjadi label teks yang bermakna (*human-readable*).

### D. Relasi Antar-Modul Terverifikasi (`join_registry`)
* Menyimpan kunci relasi resmi antar-tabel tanpa perlu mereka-reka join:
  * `kor_rt` $\leftrightarrow$ `kor_individu`: `["URUT"]` (One-to-Many).
  * `kor_rt` $\leftrightarrow$ `kp_bp41` / `kp_bp42` / `kp_bp43`: `["URUT"]` (One-to-One).
  * `kor_individu` $\leftrightarrow$ `kp_bp41`: `["URUT"]` (Many-to-One).
  * Hirarki Spasial: `["R101", "R102"]` (Provinsi & Kabupaten/Kota).
  * Desain Survei: `["PSU", "SSU"]` (Sampling units & stratifikasi).

---

## 4. Fungsi-Fungsi yang Tersedia (`R/utils.R`)

Repositori menyediakan fungsi-fungsi R modular yang siap dipanggil:

### 1. `lookup_variable(term, module = NULL, year = NULL)`
Mencari variabel di dalam `variable_registry` berdasarkan nama variabel atau deskripsi label pertanyaan.

```r
source("R/utils.R")

# Cari variabel terkait pendidikan di seluruh modul
lookup_variable("pendidikan")

# Cari variabel terkait bansos khusus di modul rumah tangga (kor_rt)
lookup_variable("bansos", module = "kor_rt")

# Cari variabel pengeluaran pada tahun tertentu
lookup_variable("pengeluaran", year = 2023)
```

### 2. `lookup_labels(var_name, year = NULL)`
Mengambil seluruh opsi kategori/label dari suatu variabel berkategori.

```r
# Cek kategori hubungan anggota keluarga (B4K2 / R402)
lookup_labels("B4K2")

# Cek klasifikasi daerah perkotaan/perdesaan (R105)
lookup_labels("R105")
```

### 3. `get_join_keys(from_tbl, to_tbl)`
Mengambil informasi kunci relasi yang valid untuk menggabungkan dua tabel survei.

```r
# Cek kunci penggabungan modul rumah tangga dan individu
get_join_keys("kor_rt", "kor_individu")

# Cek relasi modul individu ke konsumsi makanan (kp_bp41)
get_join_keys("kor_individu", "kp_bp41")
```

### 4. Manajemen Koneksi Database
* `get_metadata_con()`: Membuka koneksi DBI ke [database/metadata.db](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/database/metadata.db).
* `get_susenas_con()`: Membuka koneksi DBI ke [database/susenas.db](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/database/susenas.db).
* `query_metadata(sql, params)`: Menjalankan query terparameter ke `metadata.db` secara aman dan otomatis menutup koneksi.

---

## 5. Skrip Otomasi Pipeline (`R/`)

| Skrip | Peran / Fungsi |
| :--- | :--- |
| `R/00_setup.R` | Memastikan struktur folder ada, membuat skema SQLite dengan constraint unik, serta membuat indeks B-tree untuk performa sub-millisecond. |
| `R/01_build_catalog.R` | Menelusuri hirarki direktori `SUSENAS/`, mendeteksi tahun, modul, dan format berkas, lalu memperbarui tabel `survey_catalog`. |
| `R/02_build_registry.R` | Membaca berkas layout Excel secara otomatis menggunakan `readxl`, mengekstrak metadata kolom dan tabel label nilai dengan transaksi cepat (`dbWithTransaction`), lalu mendaftarkan kunci relasi. |

---

## 6. Standar Output Analitis

Setiap analisis yang diproduksi oleh framework ini mengikuti format baku:

1. **Objective:** Pernyataan ringkas tujuan riset.
2. **Variables Used:** Tabel variabel yang digunakan beserta label resmi dan modul asalnya.
3. **SQL Block:** Query SQLite teroptimasi (agregasi & filter sebelum diekspor ke R).
4. **R Script Block:** Skrip tidyverse untuk formatting, pelabelan faktor, dan penataan tabel.
5. **ggplot2 Figure:** Visualisasi bertema `theme_minimal()` lengkap dengan judul, subjudul wilayah/tahun, dan caption sumber resmi (`Source: SUSENAS Jawa Barat {year}`).
6. **Academic Interpretation:** Interpretasi berbasis temuan empiris.
