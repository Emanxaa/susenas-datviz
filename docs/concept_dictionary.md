# SUSENAS Concept & Synonym Dictionary

Dokumen ini memuat kamus konsep semantik, sinonim, kata kunci pencarian, dan variabel survei BPS SUSENAS yang terpetakan lintas tahun (2019?2023). Kamus ini menjadi rujukan modul `concept_mapper.py` dalam menerjemahkan pertanyaan riset (*Research Question*) ke variabel operasional.

---

## 1. Daftar Konsep & Pemetaan Sinonim

### A. `children_under5` (Anak Balita & Usia Dini)
* **Domain**: Demografi & Kesehatan Anak
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `balita`, `anak balita`, `anak usia dini`, `bayi`, `batita`, `anak kecil`, `stunting`
  * Bahasa Inggris: `children under five`, `under-five`, `toddler`, `infant`, `preschool child`
* **Variabel Terkait**:
  * `R407`: Umur Anggota Rumah Tangga (Tahun) pada modul `kor_individu`
  * `R407 < 5` / `JART014`: Indikator keberadaan anak usia 0?4 tahun dalam rumah tangga
  * `R301`: Jumlah seluruh anggota rumah tangga
* **Tingkat Agregasi**: Individu (`kor_individu`) diagregasikan ke Rumah Tangga via `URUT` (`COUNT(CASE WHEN R407 < 5 THEN 1 END) AS n_balita`).

---

### B. `food_insecurity` (Kerawanan Pangan / FIES)
* **Domain**: Pangan & Nutrisi
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `kerawanan pangan`, `rawan pangan`, `ketahanan pangan`, `kelaparan`, `kurang pangan`, `fies`, `skala pengalaman kerawanan pangan`, `pola konsumsi gizi`
  * Bahasa Inggris: `food insecurity`, `food security`, `hunger`, `fies`, `food access`
* **Variabel Terkait**:
  * FIES 8 Indikator:
    * 2019: `R1501` ? `R1508` (`kor_rt` / `kp_bp43`)
    * 2020: `R1601` ? `R1608` (`kor_rt` / `kp_bp43`)
    * 2021?2023: `R1701` ? `R1708` (`kor_rt` / `kp_bp43`)
  * Konsumsi Gizi: `KALORI_KAP` (kkal/kapita/hari), `PROTE_KAP` (gram/kapita/hari) pada `kp_bp43`
  * Pengeluaran: `FOOD` (pengeluaran makanan sebulan) pada `kp_bp43`
* **Tingkat Agregasi**: Rumah Tangga (`URUT`).

---

### C. `water_sanitation` (Akses Air Bersih & Sanitasi / WASH)
* **Domain**: Sanitasi & WASH (SDGs Pilar 6)
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `air`, `air bersih`, `air minum`, `sanitasi`, `jamban`, `kloset`, `septik`, `wash`, `tinja`, `bab`, `buang air besar`
  * Bahasa Inggris: `water`, `sanitation`, `wash`, `drinking water`, `latrine`, `toilet`, `hygiene`
* **Variabel Terkait**:
  * Sumber Air Minum: `R1710A` (2019?2020), `R1810A` (2021?2023)
  * Fasilitas BAB / Kloset: `R1709A` (2019?2020), `R1809A` (2021?2023)
  * Jenis Kloset: `R1809B` (Leher angsa, dll)
  * Tempat Pembuangan Akhir Tinja: `R1809C` (Tangki septik, dll)
* **Tingkat Agregasi**: Rumah Tangga (`kor_rt`).

---

### D. `social_assistance` (Perlindungan Sosial / Bantuan Sosial Pemerintah)
* **Domain**: Perlindungan Sosial & Penanggulangan Kemiskinan
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `bansos`, `bantuan sosial`, `pkh`, `bpnt`, `sembako`, `blt`, `subsidi`, `kartu sembako`, `bantuan pangan`, `program keluarga harapan`
  * Bahasa Inggris: `social assistance`, `social protection`, `cash transfer`, `food voucher`, `poverty alleviation`
* **Variabel Terkait**:
  * PKH: `R1201A` (2019?2020), `R2204A` (2021?2023)
  * BPNT / Kartu Sembako: `R1202A` (2019?2020), `R2207` (2021?2023)
  * BLT BBM / Desa: `R2209A`, `R2209B` (2022?2023)
* **Tingkat Agregasi**: Rumah Tangga (`kor_rt`).

---

### E. `food_expenditure_share` (Pangsa Pengeluaran Pangan / Hukum Engel)
* **Domain**: Pengeluaran & Pangan
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `pangsa pangan`, `pangsa pengeluaran pangan`, `hukum engel`, `proporsi makanan`, `belanja makanan`, `beban pangan`
  * Bahasa Inggris: `food expenditure share`, `food share`, `engel law`, `food budget share`
* **Variabel Terkait**:
  * `FOOD`: Total pengeluaran makanan sebulan (Rupiah) pada `kp_bp43`
  * `EXPEND`: Total pengeluaran rumah tangga sebulan (Rupiah) pada `kp_bp43`
  * `Pangsa Pangan (%)`: `(FOOD / EXPEND) * 100`
  * `KAPITA`: Pengeluaran per kapita sebulan pada `kp_bp43`
* **Tingkat Agregasi**: Rumah Tangga (`URUT`).

---

### F. `household_welfare` & `poverty` (Kesejahteraan & Kemiskinan)
* **Domain**: Kesejahteraan Ekonomi
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `kemiskinan`, `miskin`, `kesejahteraan`, `garis kemiskinan`, `desil`, `kuintil`, `dhuafa`
  * Bahasa Inggris: `poverty`, `welfare`, `decile`, `poor households`
* **Variabel Terkait**:
  * `KAPITA`: Pengeluaran per kapita sebulan
  * `EXPEND`: Pengeluaran total
  * `R301`: Jumlah anggota rumah tangga
* **Tingkat Agregasi**: Rumah Tangga (`kp_bp43` / `kor_rt`).

---

### G. `education_head` (Pendidikan Kepala Rumah Tangga)
* **Domain**: Pendidikan & Ketenagakerjaan
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `pendidikan`, `sekolah`, `ijazah`, `tamat sd`, `smp`, `sma`, `sarjana`, `krt sekolah`
  * Bahasa Inggris: `education`, `schooling`, `household head education`
* **Variabel Terkait**:
  * `R403 = 1`: Hubungan dengan KRT (1 = Kepala Rumah Tangga)
  * `R612`: Jenjang pendidikan yang sedang / pernah diikuti
  * `R614`: Ijazah / STTB tertinggi yang dimiliki
* **Tingkat Agregasi**: Individu (`kor_individu`) filter `R403 = 1`.

---

### H. `rural_urban` (Disparitas Spasial Perkotaan vs Perdesaan)
* **Domain**: Spasial & Geografi
* **Sinonim / Kata Kunci**:
  * Bahasa Indonesia: `desa`, `kota`, `desa kota`, `perdesaan`, `perkotaan`, `kabupaten`, `wilayah`
  * Bahasa Inggris: `rural`, `urban`, `district`, `regency`
* **Variabel Terkait**:
  * `R105`: Klasifikasi Desa/Kota (1 = Perkotaan, 2 = Perdesaan)
  * `R102`: Kode Kabupaten/Kota (1 s.d. 27 di Jawa Barat)
  * `WERT`: Bobot penimbang survei
* **Tingkat Agregasi**: Seluruh tabel survei.

---

## 2. Struktur Data JSON In-Memory Modul Concept Mapper

Modul `concept_mapper.py` mengompilasi kamus ini ke dalam struktur evaluasi berbobot (*weighted token matching*):

```json
{
  "concepts": ["children_under5", "food_insecurity"],
  "candidate_variables": [
    "R407",
    "R301",
    "R1701",
    "R1702",
    "R1703",
    "R1704",
    "R1705",
    "R1706",
    "R1707",
    "R1708",
    "KALORI_KAP",
    "PROTE_KAP",
    "FOOD"
  ],
  "sources": ["evidence.db", "metadata.db"]
}
```
