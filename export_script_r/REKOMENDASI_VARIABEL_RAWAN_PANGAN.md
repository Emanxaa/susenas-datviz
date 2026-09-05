# Kamus Rekomendasi Variabel: Identifikasi Daerah Rawan Pangan Jawa Barat (SUSENAS 2023)

Dokumen ini merupakan panduan referensi cepat (*quick reference & cheat-sheet*) yang mengompilasi seluruh variabel resmi BPS yang relevan, valid, dan terverifikasi di dalam basis data [database/metadata.db](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/database/metadata.db) untuk studi kasus **Identifikasi, Pemetaan, dan Analisis Daerah Rawan Pangan di Provinsi Jawa Barat**.

---

## 1. Tabel Master Rekomendasi Variabel (Ringkasan Akses Cepat)

| Variabel | Label Resmi BPS | Modul Asal | Tabel / View SQLite | Tipe Data | Peran Utama dalam Analisis Rawan Pangan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`R102`** | Kode Kabupaten/kota | `kor_rt` | `kor_rt_2023` / View | Nominal (Kode 2 digit) | Unit spasial utama analisis pemetaan 27 daerah |
| **`R105`** | Klasifikasi perkotaan/perdesaan | `kor_rt` | `kor_rt_2023` / View | Nominal (1=Kota, 2=Desa) | Evaluasi kesenjangan struktural perdesaan vs perkotaan |
| **`URUT`** | Nomor urut rumah tangga (*renumbering*) | `kor_rt`, `kp_bp43` | Semua tabel | Integer | Kunci relasi join One-to-One antar modul RT dan Pengeluaran |
| **`WERT`** | Penimbang untuk Estimasi Rumah Tangga | `kp_bp43` | `kp_bp43_2023` / View | Kontinu | Bobot sampling agregasi estimasi populasi representatif |
| **`FOOD`** | Rata-rata Pengeluaran Makanan Rumah Tangga Sebulan | `kp_bp43` | `kp_bp43_2023` / View | Kontinu (Rupiah) | Pembilang rasio beban belanja pangan (*Hukum Engel*) |
| **`EXPEND`** | Total Pengeluaran Rumah Tangga Sebulan | `kp_bp43` | `kp_bp43_2023` / View | Kontinu (Rupiah) | Penyebut rasio pangan & indikator kapasitas daya beli RT |
| **`KAPITA`** | Rata-rata Pengeluaran Perkapita Sebulan | `kp_bp43` | `kp_bp43_2023` / View | Kontinu (Rupiah) | Normalisasi garis kemiskinan dan disparitas ekonomi RT |
| **`KALORI_KAP`** | Banyaknya Konsumsi Kalori Perkapita Sehari | `kp_bp43` | `kp_bp43_2023` / View | Kontinu (Kkal) | Indikator kecukupan energi (Ambang batas WNPG: $\ge 2.100$ Kkal) |
| **`PROTE_KAP`** | Banyaknya Konsumsi Protein Perkapita Sehari | `kp_bp43` | `kp_bp43_2023` / View | Kontinu (Gram) | Indikator kecukupan zat pembangun (Ambang batas WNPG: $\ge 57$ Gr) |
| **`R1701`–`R1708`**| Pertanyaan Pengalaman Kerawanan Pangan (FIES) | `kor_rt` | `kor_rt_2023` | Nominal (1=Ya, 5=Tidak) | 8 dimensi pengalaman kelaparan dan kecemasan pangan (FAO/BPS) |
| **`R2207`** | Penerima Bantuan Pangan Non Tunai (BPNT/Sembako) | `kor_rt` | `kor_rt_2023` | Nominal (1=Ya, 5=Tidak) | Jaring pengaman sosial pangan pemerintah pusat |
| **`R2204A`** | Penerima Program Keluarga Harapan (PKH) | `kor_rt` | `kor_rt_2023` | Nominal (1=Ya, 5=Tidak) | Bansos bersyarat untuk keluarga prasejahtera rentan |
| **`R301`** | Banyaknya anggota rumah tangga (ART) | `kor_rt` | `kor_rt_2023` | Integer | Beban ketergantungan konsumsi dalam keluarga |
| **`R403`** | Hubungan dengan kepala rumah tangga | `kor_individu` | `kor_ind1_2023` | Nominal (1=KRT) | Filter identitas Kepala Rumah Tangga |
| **`R405`** | Jenis kelamin KRT | `kor_individu` | `kor_ind1_2023` / View | Nominal (1=L, 2=P) | Analisis kerentanan pangan kepala keluarga perempuan |
| **`R612`** | Jenjang pendidikan tertinggi yang pernah diikuti KRT | `kor_individu` | `kor_ind1_2023` / View | Kategorik (0–24) | Modal manusia & determinan daya tahan ekonomi keluarga |
| **`R1809A`** | Fasilitas tempat buang air besar (Sanitasi) | `kor_rt` | `kor_rt_2023` | Nominal (1–6) | Faktor lingkungan penyerapan nutrisi biologis (WASH) |
| **`R1810A`** | Sumber air utama yang digunakan untuk minum | `kor_rt` | `kor_rt_2023` | Nominal (1–11) | Akses air minum layak untuk pencegahan infeksi & stunting |

---

## 2. Rincian Metadata & Label Kategori Resmi (*Value Labels*)

Berikut adalah kode numerik dan deskripsi label resmi dari tabel `value_labels` di dalam `database/metadata.db`:

### Dimensi 1: Wilayah Geografis & Klasifikasi Daerah
* **`R101` (Provinsi):**
  * `32` = Jawa Barat
* **`R102` (Kabupaten / Kota di Jawa Barat):**
  * **Wilayah Kabupaten (01–18):**
    `1 = Kab. Bogor` | `2 = Kab. Sukabumi` | `3 = Kab. Cianjur` | `4 = Kab. Bandung` | `5 = Kab. Garut` | `6 = Kab. Tasikmalaya` | `7 = Kab. Ciamis` | `8 = Kab. Kuningan` | `9 = Kab. Cirebon` | `10 = Kab. Majalengka` | `11 = Kab. Sumedang` | `12 = Kab. Indramayu` | `13 = Kab. Subang` | `14 = Kab. Purwakarta` | `15 = Kab. Karawang` | `16 = Kab. Bekasi` | `17 = Kab. Bandung Barat` | `18 = Kab. Pangandaran`
  * **Wilayah Kota (71–79):**
    `71 = Kota Bogor` | `72 = Kota Sukabumi` | `73 = Kota Bandung` | `74 = Kota Cirebon` | `75 = Kota Bekasi` | `76 = Kota Depok` | `77 = Kota Cimahi` | `78 = Kota Tasikmalaya` | `79 = Kota Banjar`
* **`R105` (Tipe Wilayah):**
  * `1` = Perkotaan
  * `2` = Perdesaan

---

### Dimensi 2: Keterjangkauan Ekonomi & Beban Belanja Pangan
Variabel berasal dari modul konsumsi dan pengeluaran `kp_bp43` (Sumber: `2023 KP - Layout_data_Susenas.xlsx`):
* **`FOOD`:** Pengeluaran sebulan untuk kelompok padi-padian, umbi-umbian, ikan, daging, telur, susu, sayuran, kacang-kacangan, buah-buahan, minyak, bahan minuman, bumbu, makanan jadi, dan rokok.
* **`EXPEND`:** Total pengeluaran (`FOOD + NONFOOD`).
* **`KAPITA`:** Pengeluaran per kapita sebulan (`EXPEND / R301`).
* **Formula Analitis Turunan:**
  * **Pangsa Pangan (%):** `(FOOD / EXPEND) * 100`
  * **Rumah Tangga Rentan Pangan:** `CASE WHEN (FOOD * 1.0 / EXPEND) > 0.60 THEN 1 ELSE 0 END` *(Ambang batas >60% anggaran belanja habis untuk makan)*.

---

### Dimensi 3: Kecukupan Asupan Gizi Makro
Variabel berasal dari modul konsumsi rekapitulasi `kp_bp43`:
* **`KALORI_KAP`:** Rerata konsumsi energi harian per orang (Kkal/kapita/hari).
  * Standar Minimal WNPG: $\ge 2.100$ Kkal.
  * Formula Defisit Kalori: `CASE WHEN KALORI_KAP < 2100 THEN 1 ELSE 0 END`.
  * Formula Defisit Kalori Berat: `CASE WHEN KALORI_KAP < 1700 THEN 1 ELSE 0 END`.
* **`PROTE_KAP`:** Rerata konsumsi protein harian per orang (Gram/kapita/hari).
  * Standar Minimal WNPG: $\ge 57$ Gram.
  * Formula Defisit Protein: `CASE WHEN PROTE_KAP < 57 THEN 1 ELSE 0 END`.

---

### Dimensi 4: Skala Kerawanan Pangan FIES (*Food Insecurity Experience Scale*)
Variabel berasal dari modul `kor_rt` Blok XVII Pertanyaan Kerawanan Pangan (Sumber: `KOR 2023 Layout_data_Susenas.xlsx`).
Seluruh variabel memiliki opsi kode nilai seragam:
$$\text{Kode Nilai: } 1 = \text{Ya}, \quad 5 = \text{Tidak}, \quad 8 = \text{Tidak tahu}, \quad 9 = \text{Menolak menjawab}$$

| Kode Variabel | Bunyi Pertanyaan Resmi Kuesioner BPS | Dimensi Kerawanan FIES |
| :--- | :--- | :--- |
| **`R1701`** | Apakah khawatir tidak akan memiliki cukup makanan karena kekurangan uang atau sumber daya lainnya? | Kekhawatiran (*Uncertainty / Worry*) |
| **`R1702`** | Apakah ada saat dimana tidak dapat menyantap makanan sehat dan bergizi karena kekurangan uang atau sumber daya lainnya? | Kualitas Makanan Rendah (*Inadequate diet quality*) |
| **`R1703`** | Apakah hanya menyantap sedikit jenis makanan karena kekurangan uang atau sumber daya lainnya? | Variasi Makanan Terbatas (*Monotonous diet*) |
| **`R1704`** | Apakah pernah melewatkan satu waktu makan (misal tidak makan siang) pada suatu hari tertentu karena tidak cukup uang? | Melewatkan Jam Makan (*Skipped meal*) |
| **`R1705`** | Apakah makan lebih sedikit daripada seharusnya karena kekurangan uang atau sumber daya lainnya? | Kuantitas Berkurang (*Ate less than desired*) |
| **`R1706`** | Apakah pernah kehabisan makanan di rumah karena kekurangan uang atau sumber daya lainnya? | Kehabisan Makanan (*Ran out of food*) |
| **`R1707`** | Apakah merasa lapar tetapi tidak makan karena tidak cukup uang atau sumber daya lainnya? | Menahan Lapar (*Hungry but didn't eat*) |
| **`R1708`** | Apakah tidak makan seharian penuh karena kekurangan uang atau sumber daya lainnya? | Kelaparan Seharian (*Whole day without eating*) |

* **Skor Baku FIES Raw Score (0–8):**
  ```sql
  (CASE WHEN R1701 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1702 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1703 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1704 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1705 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1706 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1707 = 1 THEN 1 ELSE 0 END) +
  (CASE WHEN R1708 = 1 THEN 1 ELSE 0 END)
  ```
  * **Rawan Pangan Moderat:** $\text{Skor FIES} \ge 1$
  * **Rawan Pangan Berat / Akut:** $\text{Skor FIES} \ge 4$ atau `R1706=1` / `R1707=1` / `R1708=1`.

---

### Dimensi 5: Jaring Pengaman Sosial Pangan (Bansos)
Variabel berasal dari modul `kor_rt` Blok XXII:
* **`R2207` (Bantuan Pangan Non Tunai / BPNT / Kartu Sembako):**
  * `1` = Ya (Penerima)
  * `5` = Tidak (Bukan Penerima)
* **`R2204A` (Program Keluarga Harapan / PKH):**
  * `1` = Ya
  * `5` = Tidak
  * `8` = Tidak tahu
* **`R2209A` (Bantuan Langsung Tunai BBM / Kompensasi Energi):**
  * `1` = Ya
  * `5` = Tidak

---

### Dimensi 6: Demografi KRT & Kapasitas Rumah Tangga
* **`R301` (Ukuran Rumah Tangga):** Jumlah ART yang tinggal di RT.
* **`R403` (Hubungan dengan KRT):** Wajib filter `R403 = 1` (Kepala Rumah Tangga).
* **`R405` (Jenis Kelamin KRT):** `1 = Laki-laki`, `2 = Perempuan` (KRT Perempuan rentan ganda).
* **`R407` (Umur KRT):** Usia dalam tahun genap.
* **`R612` (Pendidikan Tertinggi KRT):**
  * `0` = Tidak/Belum Pernah Sekolah
  * `1–5` = SD / MI / Sederajat
  * `6–10` = SMP / MTs / Sederajat
  * `11–17` = SMA / MA / SMK / Sederajat
  * `18–24` = Diploma / S1 / S2 / S3

---

### Dimensi 7: Lingkungan Sanitasi & Air Bersih (Determinan Biologis WASH)
Penyerapan nutrisi makanan terhambat jika sanitasi buruk (menyebabkan infeksi usus kronis & stunting):
* **`R1809A` (Fasilitas Buang Air Besar):**
  * `1` = Ada, digunakan hanya ART sendiri *(Sanitasi Layak Pribadi)*
  * `2` = Ada, digunakan bersama rumah tangga tertentu *(Sanitasi Bersama)*
  * `3` = Ada, di MCK komunal
  * `4` = Ada, di MCK Umum/siapapun menggunakan
  * `5` = Ada, ART tidak menggunakan
  * `6` = **Tidak ada fasilitas (BABS / Buang Air Besar Sembarangan - Sangat Rentan)**
* **`R1810A` (Sumber Air Utama untuk Minum):**
  * `1` = Air kemasan bermerk
  * `2` = Air isi ulang
  * `3` = Leding
  * `4` = Sumur bor/pompa
  * `5` = Sumur terlindung
  * `6` = **Sumur tak terlindung (Air Tak Layak)**
  * `7` = Mata air terlindung
  * `8` = **Mata air tak terlindung (Air Tak Layak)**
  * `9` = **Air permukaan: sungai, danau/waduk, kolam, irigasi (Sangat Berbahaya)**
  * `10` = Air hujan
  * `11` = Lainnya

---

## 3. Cara Mengakses Metadata Secara Instan di R

Gunakan fungsi pembantu yang sudah tersedia di [`R/utils.R`](file:///D:/IPB/KULIAH/S1/SD/Tugas/P3/R/utils.R):

```r
source("R/utils.R")

# 1. Cari variabel berdasarkan kata kunci label atau nama
lookup_variable("makanan")
lookup_variable("kalori")
lookup_variable("air")

# 2. Cek seluruh kode nilai dan label suatu variabel
lookup_labels("R1701")  # Cek label pertanyaan FIES
lookup_labels("R1809A") # Cek kategori fasilitas sanitasi
lookup_labels("R102")   # Cek kode 27 kab/kota

# 3. Labeling otomatis vektor kode menjadi label teks
map_value_labels("R102", c(3, 5, 12, 73)) 
# Output: "Kab. Cianjur", "Kab. Garut", "Kab. Indramayu", "Kota Bandung"

map_value_labels("R105", c(1, 2))
# Output: "Perkotaan", "Perdesaan"
```

---

## 4. Snippet Query SQL Siap Pakai untuk Ekstraksi Cepat

Kueri berikut mengekstrak seluruh dimensi di atas sekaligus secara terbobot (`WERT`) dari basis data analitis:

```sql
SELECT 
  r.R102 AS kode_kabkot,
  r.R105 AS kode_wilayah,
  COUNT(*) AS n_sampel,
  ROUND(SUM(k.WERT), 0) AS estimasi_populasi_rt,
  
  -- Beban Belanja Pangan (Hukum Engel)
  ROUND((SUM(k.FOOD * k.WERT) / SUM(k.EXPEND * k.WERT)) * 100.0, 2) AS pangsa_pangan_persen,
  ROUND(SUM(CASE WHEN (k.FOOD * 1.0 / k.EXPEND) > 0.60 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_beban_pangan_tinggi,
  
  -- Defisit Nutrisi Makro
  ROUND(SUM(CASE WHEN k.KALORI_KAP < 2100 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_kalori,
  ROUND(SUM(CASE WHEN k.PROTE_KAP < 57 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS pct_defisit_protein,
  
  -- Prevalensi Kerawanan FIES BPS/FAO
  ROUND(SUM(CASE WHEN (
    (CASE WHEN r.R1701 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1702 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1703 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1704 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1705 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1706 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1707 = 1 THEN 1 ELSE 0 END) +
    (CASE WHEN r.R1708 = 1 THEN 1 ELSE 0 END)
  ) >= 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS prevalensi_fies_persen,
  
  -- Jaring Pengaman Bansos
  ROUND(SUM(CASE WHEN r.R2207 = 1 THEN k.WERT ELSE 0 END) * 100.0 / SUM(k.WERT), 2) AS cakupan_bpnt_persen

FROM kor_rt_2023 r
INNER JOIN kp_bp43_2023 k ON r.URUT = k.URUT
WHERE k.EXPEND > 0 AND k.FOOD > 0 AND k.WERT > 0
GROUP BY r.R102, r.R105;
```
