# Laporan Verifikasi & Pengujian SUSENAS Semantic Planner

**Waktu Pengujian:** 2026-09-04 16:19:35 WIB  
**Status Keseluruhan:** **SEMUA UJI LOLOS (ALL PASSED)** (20/20 Uji Berhasil - 100.0%)  
**Database Terverifikasi:** `database/metadata.db` & `database/susenas.db`

---

## 1. Ringkasan Pengujian

| No | Modul Uji | Komponen yang Diverifikasi | Status | Catatan / Hasil Empiris |
| :--- | :--- | :--- | :---: | :--- |
| 1 | Semantic Planner Suite | Concept Registry Populated | <span style='color:green; font-weight:bold;'>PASS</span> | (Found 9 concepts) |
| 2 | Semantic Planner Suite | Concept Variables Registered in variable_registry | <span style='color:green; font-weight:bold;'>PASS</span> | (All 52 variables grounded) |
| 3 | Semantic Planner Suite | Multi-Year Compatibility Matrix Populated | <span style='color:green; font-weight:bold;'>PASS</span> | (Found 23 records) |
| 4 | Semantic Planner Suite | Join Registry Populated with Link Keys | <span style='color:green; font-weight:bold;'>PASS</span> | (Found 7 join paths) |
| 5 | Semantic Planner Suite | Physical Tables & Views Exist | <span style='color:green; font-weight:bold;'>PASS</span> | (All 8 tables/views found) |
| 6 | Semantic Planner Suite | KOR RT Sample Size Exact | <span style='color:green; font-weight:bold;'>PASS</span> | (25,890 households) |
| 7 | Semantic Planner Suite | KP BP43 Sample Size Exact | <span style='color:green; font-weight:bold;'>PASS</span> | (25,890 households) |
| 8 | Semantic Planner Suite | KOR INDIVIDU Sample Size Exact | <span style='color:green; font-weight:bold;'>PASS</span> | (84,688 individuals) |
| 9 | Semantic Planner Suite | v_household_expenditure_2023 Physical Columns | <span style='color:green; font-weight:bold;'>PASS</span> | (All 15 required fields present) |
| 10 | Semantic Planner Suite | v_head_household_welfare_2023 Physical Columns | <span style='color:green; font-weight:bold;'>PASS</span> | (All 14 required fields present) |
| 11 | Semantic Planner Suite | kor_ind1_2023 Physical Columns (Demografi, Edu, Kerja, TIK) | <span style='color:green; font-weight:bold;'>PASS</span> | (All 15 required fields present) |
| 12 | Semantic Planner Suite | Data Non-Negativity & Cleanliness Audit | <span style='color:green; font-weight:bold;'>PASS</span> | (Expenditure, Calories, and Weights strictly > 0) |
| 13 | Semantic Planner Suite | Join Key Integrity: kor_rt <-> kp_bp43 [URUT] | <span style='color:green; font-weight:bold;'>PASS</span> | (Match: 25890/25890 = 100.0%) |
| 14 | Semantic Planner Suite | Join Key Integrity: kor_rt <-> kor_ind1 [URUT, R403=1] | <span style='color:green; font-weight:bold;'>PASS</span> | (Each household has exactly 1 KRT: 100.0%) |
| 15 | Semantic Planner Suite | Spatial Hierarchy: R101 = 32, 27 Kab/Kota Jawa Barat | <span style='color:green; font-weight:bold;'>PASS</span> | (Provinsi: 32, Kab/Kota: 27) |
| 16 | Semantic Planner Suite | Planner: Scenario 1: Ketahanan Pangan (Food Share vs Education) | <span style='color:green; font-weight:bold;'>PASS</span> | (24 rows computed, plot generated in 0.50s) |
| 17 | Semantic Planner Suite | Planner: Scenario 2: Ketimpangan Pengeluaran (Urban vs Rural) | <span style='color:green; font-weight:bold;'>PASS</span> | (2 rows computed, plot generated in 0.19s) |
| 18 | Semantic Planner Suite | Planner: Scenario 3: Perlindungan Sosial (PKH Bansos vs Nutrition) | <span style='color:green; font-weight:bold;'>PASS</span> | (2 rows computed, plot generated in 0.16s) |
| 19 | Semantic Planner Suite | Planner: Scenario 4: Ketenagakerjaan (Labor & Employment) | <span style='color:green; font-weight:bold;'>PASS</span> | (27 rows computed, plot generated in 0.17s) |
| 20 | Semantic Planner Suite | Planner: Scenario 5: Fasilitas Sanitasi & Air Bersih (WASH) | <span style='color:green; font-weight:bold;'>PASS</span> | (2 rows computed, plot generated in 0.16s) |

---

## 2. Temuan Integritas Data & Relasi

1. **Grounded Columns:** 100% variabel yang direkomendasikan oleh mesin Semantic Planner terbukti ada secara fisik pada tabel asal (`kor_rt_2023`, `kor_ind1_2023`, `kp_bp43_2023`) dan kamus data resmi BPS.
2. **Harmonisasi Blok:** Verifikasi membuktikan pergeseran nomor blok (mis. Ketenagakerjaan berada di Blok VII `R703_A`–`R709`, TIK di Blok VIII `R801`–`R808`, dan FIES di Blok XVII `R1701`–`R1708`) telah dipetakan secara akurat tanpa kekeliruan asumsi.
3. **Integritas Relasional:** Join kunci rumah tangga (`URUT`) memiliki tingkat kecocokan 100% antara modul KOR dan KP. Setiap rumah tangga terverifikasi memiliki tepat satu Kepala Rumah Tangga (`R403 = 1`).
4. **Performa Agregasi SQLite:** Kueri SQLite ETL mengeksekusi penyaringan 25.890 baris sampel rumah tangga dan pembobotan sampling `WERT` dalam waktu rata-rata di bawah 300 ms.

