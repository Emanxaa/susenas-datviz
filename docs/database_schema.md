# Database Schema Documentation

Research Discovery Engine mengelola dua basis data SQLite terpisah dengan prinsip pemisahan tanggung jawab (*separation of concerns*):
1. `database/metadata.db` (Metadata BPS SUSENAS & Kompatibilitas Lintas Tahun)
2. `database/evidence.db` (Bukti Literatur Ilmiah, Temuan, dan Variabel)

---

## 1. Database: `database/metadata.db`

### Tabel: `variable_compatibility`
Menyimpan kamus pemetaan konsep variabel survei SUSENAS dari 2019 hingga 2023.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `id` | INTEGER PK AUTO | ID unik kompatibilitas |
| `variable_concept` | TEXT UNIQUE | Nama konsep standar (misal: "Kerawanan Pangan FIES") |
| `domain` | TEXT | Domain tematik (misal: "Pangan & Nutrisi") |
| `var_2019` | TEXT | Nama variabel resmi BPS tahun 2019 |
| `var_2020` | TEXT | Nama variabel resmi BPS tahun 2020 |
| `var_2021` | TEXT | Nama variabel resmi BPS tahun 2021 |
| `var_2022` | TEXT | Nama variabel resmi BPS tahun 2022 |
| `var_2023` | TEXT | Nama variabel resmi BPS tahun 2023 |
| `module` | TEXT | Modul survei asal (`kor_rt`, `kor_individu`, `kp_bp43`, dll) |
| `compatibility_status` | TEXT | `IDENTICAL`, `RENUMBERED`, atau `IDENTICAL_CONCEPT` |
| `notes` | TEXT | Catatan metodologis atau perpindahan blok kuisioner |

---

### Tabel: `survey_catalog`
Katalog seluruh berkas survei SUSENAS Jawa Barat yang terdaftar.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `id` | INTEGER PK AUTO | ID unik katalog |
| `year` | INTEGER | Tahun survei (2019?2023) |
| `province` | TEXT | Nama provinsi (Jawa Barat) |
| `module` | TEXT | Kode modul (`kor_rt`, `kor_ind1`, `kp_bp41`, `kp_bp43`) |
| `table_name` | TEXT | Nama tabel standar di SQLite |
| `file_name` | TEXT | Nama berkas resmi CSV/DBF dari BPS |
| `file_path` | TEXT | Lokasi path relatif berkas |
| `file_format` | TEXT | Format berkas (`csv` atau `dbf`) |
| `n_rows` | INTEGER | Jumlah baris data sampel |
| `n_cols` | INTEGER | Jumlah kolom |

---

### Tabel: `concept_registry`
Katalog domain penelitian dan rekomendasi variabel utama, kovariat, dan visualisasi.

---

## 2. Database: `database/evidence.db`

### Tabel: `papers`
Menyimpan metadata bibliografis literatur ilmiah pendukung.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `paper_id` | TEXT PK | ID unik paper (misal: `HERLINA_2020_BALITA`) |
| `title` | TEXT | Judul lengkap artikel ilmiah |
| `year` | INTEGER | Tahun publikasi |
| `authors` | TEXT | Penulis artikel |
| `source` | TEXT | Nama jurnal / prosiding / working paper |
| `file_path` | TEXT | Lokasi file markdown ringkasan di `literature/papers/` |

---

### Tabel: `concepts`
Katalog konsep semantik yang terhubung dengan literatur ilmiah.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `concept_id` | TEXT PK | Identifier konsep (misal: `children_under5`) |
| `concept` | TEXT | Label nama konsep |
| `domain` | TEXT | Domain keilmuan |

---

### Tabel: `findings`
Temuan empiris kuantitatif yang diekstraksi dari setiap literatur.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `finding_id` | TEXT PK | Identifier temuan (misal: `HERLINA_2020_BALITA_F01`) |
| `paper_id` | TEXT FK | Relasi ke `papers.paper_id` |
| `concept_id` | TEXT FK | Relasi ke `concepts.concept_id` |
| `finding` | TEXT | Kutipan temuan ilmiah / kesimpulan empiris |
| `evidence_strength` | TEXT | Kekuatan bukti (`High`, `Moderate`, `Low`) |

---

### Tabel: `finding_variables`
Menghubungkan temuan ilmiah dengan variabel spesifik SUSENAS.

| Kolom | Tipe Data | Deskripsi |
|---|---|---|
| `finding_id` | TEXT FK | Relasi ke `findings.finding_id` |
| `variable_concept` | TEXT | Kode variabel SUSENAS (misal: `R1702`, `KALORI_KAP`) |
