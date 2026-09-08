# Repository Audit Report: Research Discovery Engine

> Generated: 2026-09-08
> Target Repository: SUSENAS Research Data Platform

---

## 1. Executive Summary

Audit ini dilakukan sebagai tahap awal (Phase 1) dalam transformasi repositori data survei SUSENAS menjadi sebuah **Research Discovery Engine** yang modular, reproducible, dan berprinsip *metadata-first*. Repositori saat ini memiliki fondasi metadata yang kuat di `database/metadata.db`, namun belum memiliki lapisan penelusuran bukti literatur ilmiah (*evidence layer*), mesin pemetaan konsep otomatis (*concept mapping engine*), serta antarmuka terpadu (CLI) untuk orchestrating lazy ETL.

---

## 2. Struktur Direktori

```
d:/IPB/KULIAH/S1/SD/Tugas/P3/
??? database/
?   ??? metadata.db (532 KB) - Metadata & Variable Registry
?   ??? susenas.db (958 MB)  - Local Analytical Ingest DB
?   ??? migrations/          - Schema migration scripts
??? literature/              - Literature knowledge base
?   ??? papers/              - Raw research papers (MD, TXT, PDF)
?   ??? processed/           - Extracted annotations & facts
?   ??? index.json           - Inverted index literatur
??? research/                - Research Question specifications
?   ??? templates/           - YAML templates
??? etl/                     - Lazy ETL code generator
?   ??? generated/           - Target R extraction scripts
?   ??? templates/           - Jinja/string R templates
?   ??? utils/               - Helper libraries
??? cli/                     - Command-line interface
?   ??? research.py          - Primary research query CLI
?   ??? search.py            - Interactive exploration CLI
??? reports/                 - Generated audit & feature reports
??? docs/                    - Architecture & schema documentation
??? tests/                   - Automated Pytest test suite
??? engine/                  - Core Python orchestration engine
??? R/                       - Existing R scripts & templates
??? SUSENAS/                 - Raw survey data folder (git-ignored)
```

---

## 3. Audit Basis Data SQLite

### A. Database `database/metadata.db` (532 KB)
Database ini berfungsi sebagai *single source of truth* untuk kamus variabel, katalog file, dan kompatibilitas lintas tahun.

| Tabel | Jumlah Record | Jumlah Kolom | Fungsi Utama |
|---|:---:|:---:|---|
| `concept_registry` | 9 | 14 | Metadata Registry |
| `join_registry` | 7 | 9 | Metadata Registry |
| `survey_catalog` | 34 | 11 | Metadata Registry |
| `value_labels` | 2,196 | 7 | Metadata Registry |
| `variable_compatibility` | 23 | 13 | Metadata Registry |
| `variable_registry` | 873 | 9 | Metadata Registry |

### B. Database `database/susenas.db` (958 MB)
Database analitis lokal yang menampung data mikro hasil ingest SUSENAS.

| Tabel | Jumlah Record | Jumlah Kolom | Keterangan |
|---|:---:|:---:|---|
| `kor_ind1_2023` | 84,688 | 183 | Data Mikro / Analytical View |
| `kor_ind2_2023` | 84,688 | 111 | Data Mikro / Analytical View |
| `kor_rt_2023` | 25,890 | 199 | Data Mikro / Analytical View |
| `kp_bp41_2020` | 1,343,386 | 27 | Data Mikro / Analytical View |
| `kp_bp41_2021` | 1,379,073 | 24 | Data Mikro / Analytical View |
| `kp_bp41_2022` | 1,395,042 | 26 | Data Mikro / Analytical View |
| `kp_bp41_2023` | 1,410,333 | 25 | Data Mikro / Analytical View |
| `kp_bp42_2023` | 1,051,815 | 24 | Data Mikro / Analytical View |
| `kp_bp43_2023` | 25,890 | 20 | Data Mikro / Analytical View |

---

## 4. Analisis Komponen Kunci Saat Ini

1. **`variable_compatibility` (23 konsep)**:
   - Menyimpan pemetaan konsep kritis lintas tahun (2019-2023) seperti FIES, Bansos (PKH, BPNT), pengeluaran pangan, dan demografi.
   - Siap dipakai sebagai inti dari Feature Master Generator.

2. **`variable_registry` (873 variabel)**:
   - Menyimpan rincian seluruh variabel resmi dari kuisioner dan layout SUSENAS BPS.

3. **`survey_catalog` (34 entri)**:
   - Mencatat seluruh berkas survei dari 2019 hingga 2023 beserta modul (KOR vs KP) dan jumlah baris/kolom.

4. **`concept_registry` (9 domain konseptual)**:
   - Menyimpan domain awal (ketahanan pangan, kemiskinan, ketimpangan, dll.) beserta variabel indikator utama.

---

## 5. Komponen yang Belum Ada (Missing Components)

| Komponen | Status Sebelum Transformasi | Kebutuhan Solusi |
|---|:---:|---|
| `database/evidence.db` | Belum ada | Dibutuhkan untuk menyimpan relasi Paper -> Concept -> Finding -> Variable |
| `literature/parser.py` | Belum ada | Parser teks/markdown literatur untuk ekstraksi fakta ilmiah |
| `concept_mapper.py` | Belum ada | NLP matching & alias dictionary dari prompt riset ke konsep |
| `drive_resolver.py` | Belum ada | Verifikator status file di Google Drive vs lokal |
| `etl_generator.py` | Belum ada | Generator kode R lazy loading berbasis kolom selektif |
| `cli/research.py` | Belum ada | CLI terintegrasi yang menerima string/YAML dan memproduksi pipeline lengkap |
| Test Suite (`tests/`) | Belum ada | Pengujian otomatis untuk menjamin reproduktibilitas |

---

## 6. Rekomendasi Arsitektural

1. **Mempertahankan `database/metadata.db`**: Jangan merusak struktur tabel yang sudah ada. Cukup tambahkan indeks bila diperlukan.
2. **Membuat `database/evidence.db`**: Pisahkan basis data literatur dari metadata BPS agar *separation of concerns* tetap terjaga.
3. **Penerapan Lazy ETL**: R script yang dihasilkan harus selalu menggunakan seleksi kolom (`select`) untuk menghemat konsumsi memori laptop.
4. **Dokumentasi Terpadu**: Semua schema, workflow, dan cara menambahkan paper baru harus tercatat di folder `docs/`.
