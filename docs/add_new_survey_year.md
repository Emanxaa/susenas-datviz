# Panduan Menambahkan Tahun Survei Baru (Add New Survey Year)

Ketika data survei SUSENAS tahun baru (misalnya tahun 2024) dirilis oleh BPS, ikuti panduan ini untuk mengintegrasikannya ke dalam Research Discovery Engine.

---

## Langkah 1: Daftarkan Berkas ke `survey_catalog`

Buka database `database/metadata.db` dan tambahkan entri berkas tahun baru ke tabel `survey_catalog`:

```sql
INSERT INTO survey_catalog (
    year, province, module, table_name, file_name, file_path, file_format
) VALUES 
(2024, 'Jawa Barat', 'kor_rt', 'kor_rt_2024', '2024 Maret JABAR - SUSENAS KOR Rumah Tangga.csv', 'SUSENAS/JAWA BARAT/2024/csv/KOR/', 'csv'),
(2024, 'Jawa Barat', 'kor_ind1', 'kor_ind1_2024', '2024 Maret JABAR - SUSENAS KOR INDIVIDU PART1.csv', 'SUSENAS/JAWA BARAT/2024/csv/KOR/', 'csv'),
(2024, 'Jawa Barat', 'kp_bp41', 'kp_bp41_2024', '2024 Maret JABAR - SUSENAS KP BP 4.1.csv', 'SUSENAS/JAWA BARAT/2024/csv/Modul KP/', 'csv'),
(2024, 'Jawa Barat', 'kp_bp43', 'kp_bp43_2024', '2024 Maret JABAR - SUSENAS KP BP 4.3.csv', 'SUSENAS/JAWA BARAT/2024/csv/Modul KP/', 'csv');
```

---

## Langkah 2: Perbarui Kolom Kompatibilitas `var_2024`

Jika kuisioner 2024 memiliki penomoran variabel baru:
1. Tambahkan kolom `var_2024` di tabel `variable_compatibility` (jika belum ada):
   ```sql
   ALTER TABLE variable_compatibility ADD COLUMN var_2024 TEXT;
   ```
2. Isi pemetaan kode variabel tahun 2024 berdasarkan file `Layout_data_Susenas.xlsx` resmi BPS tahun 2024:
   ```sql
   UPDATE variable_compatibility 
   SET var_2024 = 'R1701-R1708' 
   WHERE variable_concept LIKE '%FIES%';
   ```

---

## Langkah 3: Jalankan Uji Kompatibilitas

Jalankan test suite untuk memastikan tahun 2024 dapat disintesis secara otomatis:
```bash
python -m pytest tests/
```
