# Workflow Penggunaan: Dari Research Question Menuju Dataset Siap Analisis

Panduan operasional langkah demi langkah menggunakan **Research Discovery Engine**.

---

## Alur Singkat: 4 Langkah Utama

```
[1. Ajukan Pertanyaan Riset] 
            ?
            ?
[2. Jalankan CLI Planner] 
            ?
            ?
[3. Periksa Feature Master & Unduh File yang Missing] 
            ?
            ?
[4. Jalankan Skrip Lazy ETL di R]
```

---

## Langkah 1: Merumuskan Research Question

Terdapat dua cara memasukkan ide riset ke dalam sistem:

### Cara A: Melalui Perintah Teks Langsung
Cocok untuk eksplorasi cepat. Cukup gunakan bahasa Indonesia atau Inggris:
```bash
python cli/research.py "anak balita dan kerawanan pangan"
# atau
python cli/research.py "bansos pkh bpnt dan konsumsi gizi"
# atau
python cli/research.py "akses sanitasi air bersih terhadap fies"
```

### Cara B: Melalui Berkas Spesifikasi YAML
Cocok untuk penelitian formal, skripsi, atau laporan riset. Buat berkas di folder `research/`, misalnya `research/my_rq.yaml` dengan format:
```yaml
id: "rq_my_study"
title: "Pengaruh Bantuan Sosial Terhadap Pola Konsumsi Pangan"
question: "Bagaimana efektivitas bansos BPNT terhadap konsumsi kalori rumah tangga miskin?"
concepts:
  - social_assistance
  - food_insecurity
variables:
  outcome:
    - KALORI_KAP
    - PROTE_KAP
  predictor:
    - R2207
  control:
    - R102
    - R105
    - WERT
years:
  - 2019
  - 2020
  - 2021
  - 2022
  - 2023
```
Lalu jalankan:
```bash
python cli/research.py research/my_rq.yaml
```

---

## Langkah 2: Membaca Ringkasan & Feature Master

Setelah CLI dijalankan, terminal akan menampilkan:
1. **Concepts**: Konsep semantik yang teraktivasi.
2. **Supporting Papers**: Literatur ilmiah relevan yang menjadi landasan teoritis.
3. **Variables**: Variabel survei BPS yang terpetakan lintas tahun.
4. **Missing Local**: Daftar file yang perlu diunduh dari Google Drive BPS.

Buka berkas `reports/feature_master.md` untuk melihat rincian pemetaan nama variabel tiap tahun (2019-2023) beserta catatan perubahan kode dari BPS.

---

## Langkah 3: Mengambil File dari Google Drive (Jika Missing)

Jika CLI melaporkan file berstatus `Missing`, unduh hanya file-file modul yang tertera pada bagian `Files Needed` (misalnya hanya `KOR RT` dan `KP BP 4.3`) dari Google Drive resmi BPS:
```
https://drive.google.com/drive/folders/12-1KFoASSRUt8yBPUtLX87B_8VAIu6Qx
```
Tempatkan file di folder tahun yang sesuai:
`SUSENAS/JAWA BARAT/{TAHUN}/csv/...`

---

## Langkah 4: Menjalankan Ekstraksi Lazy di R

Jalankan skrip R yang otomatis dibuat di `etl/generated/`:
```bash
Rscript etl/generated/rq001_extract.R
```
Skrip ini akan:
- Membaca **hanya** kolom target yang didefinisikan dalam Feature Master.
- Mengabaikan ratusan kolom lain sehingga penggunaan RAM tetap sangat rendah (<500 MB).
- Menggabungkan modul per rumah tangga via nomor urut `URUT`.
- Menyimpan dataset siap analisis di `output/{rq}_analytical_dataset.rds` dan preview CSV.
