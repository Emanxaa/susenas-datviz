# Panduan Menambahkan Literatur Ilmiah Baru (Add New Paper)

Sistem dirancang terbuka (*extensible*). Anda dapat menambahkan artikel jurnal atau laporan penelitian baru kapan saja tanpa mengubah kode program.

---

## Langkah 1: Buat Berkas Markdown di `literature/papers/`

Beri nama file dengan format deskriptif:
`literature/papers/paper_005_nama_penulis_tahun_topik.md`

Gunakan struktur standar berikut:

```markdown
---
paper_id: PENULIS_2023_TOPIK
title: "Judul Lengkap Publikasi Ilmiah"
year: 2023
authors: "Nama Penulis 1, Nama Penulis 2"
source: "Nama Jurnal Ilmiah, Vol. X(Y), pp. 100-115"
doi: "10.xxxx/xxxx"
---

# Abstrak & Ringkasan Temuan
Ringkasan singkat tentang metodologi dan konteks penelitian.

## Concepts
- children_under5
- food_insecurity

## Findings
- finding: "Pernyataan temuan ilmiah kuantitatif dari artikel."
  concept: children_under5
  evidence_strength: "High"
  variables: ["R407", "R301", "R1702"]
- finding: "Temuan kedua terkait variabel lain."
  concept: food_insecurity
  evidence_strength: "Moderate"
  variables: ["KALORI_KAP", "FOOD"]
```

---

## Langkah 2: Jalankan Literature Parser

Setelah berkas disimpan, jalankan parser otomatis:
```bash
python literature/parser.py
```

Sistem akan:
1. Membaca berkas markdown baru.
2. Memperbarui tabel `papers`, `concepts`, `findings`, dan `finding_variables` di `database/evidence.db`.
3. Memperbarui inverted index di `literature/index.json`.

---

## Langkah 3: Verifikasi

Jalankan pengujian cepat untuk memastikan paper baru terindeks:
```bash
python cli/search.py "PENULIS_2023_TOPIK"
```
