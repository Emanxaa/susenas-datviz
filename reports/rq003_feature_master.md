# Master Matrix Kompatibilitas Fitur SUSENAS (2019?2023)

> Disusun otomatis oleh Feature Master Generator (Research Discovery Engine).
> Menampilkan pemetaan variabel survei resmi BPS lintas tahun untuk memastikan konsistensi ekstraksi.

| Konsep / Fitur | 2019 | 2020 | 2021 | 2022 | 2023 | Modul Sumber | Status Kompatibilitas |
|:---|:---:|:---:|:---:|:---:|:---:|:---|:---:|
| **Klasifikasi Perkotaan / Perdesaan** | `R105` | `R105` | `R105` | `R105` | `R105` | kor_rt / kor_individu / kp_bp43 | IDENTICAL |
| **Kode Kabupaten / Kota** | `R102` | `R102` | `R102` | `R102` | `R102` | kor_rt / kor_individu / kp_bp43 | IDENTICAL |
| **Nomor Urut Rumah Tangga (Join Key)** | `URUT` | `URUT` | `URUT` | `URUT` | `URUT` | Semua Modul | IDENTICAL |
| **Penimbang Rumah Tangga (Sampling Weight)** | `WERT / FWT` | `WERT / FWT` | `WERT / FWT` | `WERT / FWT` | `WERT / FWT` | kp_bp43 (WERT) / kor_rt (FWT) | IDENTICAL |
| **Rata-rata Pengeluaran Makanan Sebulan** | `FOOD` | `FOOD` | `FOOD` | `FOOD` | `FOOD` | kp_bp43 | IDENTICAL |
| **Total Pengeluaran Rumah Tangga Sebulan** | `EXPEND` | `EXPEND` | `EXPEND` | `EXPEND` | `EXPEND` | kp_bp43 | IDENTICAL |
| **Pengeluaran Per Kapita Sebulan** | `KAPITA` | `KAPITA` | `KAPITA` | `KAPITA` | `KAPITA` | kp_bp43 | IDENTICAL |
| **Konsumsi Kalori Per Kapita Sehari** | `KALORI_KAP` | `KALORI_KAP` | `KALORI_KAP` | `KALORI_KAP` | `KALORI_KAP` | kp_bp43 | IDENTICAL |
| **Konsumsi Protein Per Kapita Sehari** | `PROTE_KAP` | `PROTE_KAP` | `PROTE_KAP` | `PROTE_KAP` | `PROTE_KAP` | kp_bp43 | IDENTICAL |
| **Jumlah Anggota Rumah Tangga (Ukuran RT)** | `R301` | `R301` | `R301` | `R301` | `R301` | kor_rt / kp_bp43 | IDENTICAL |
| **Kerawanan Pangan FIES (8 Indikator)** | `R1501-R1508` | `R1601-R1608` | `R1701-R1708` | `R1701-R1708` | `R1701-R1708` | kor_rt | RENUMBERED |
| **Bantuan Sosial PKH (Program Keluarga Harapan)** | `R1201A` | `R1201A` | `R2204A` | `R2204A` | `R2204A` | kor_rt | RENUMBERED |
| **Bantuan Pangan Non Tunai (BPNT / Sembako)** | `R1202A` | `R1202A` | `R2207` | `R2207` | `R2207` | kor_rt | RENUMBERED |
| **Bantuan Tunai BBM (BLT BBM)** | `-` | `-` | `-` | `R2209A` | `R2209A` | kor_rt | NEW |
| **Status Kepemilikan Bangunan Tempat Tinggal** | `R1702` | `R1702` | `R1802` | `R1802` | `R1802` | kor_rt | RENUMBERED |

### Catatan Teknis:
- **Klasifikasi Perkotaan / Perdesaan**: 1 = Perkotaan, 2 = Perdesaan. Format dan kode 100% konsisten sepanjang 2019-2023.
- **Kode Kabupaten / Kota**: Kode 2 digit BPS (01-18 Kabupaten, 71-79 Kota di Jawa Barat). Konsisten penuh.
- **Nomor Urut Rumah Tangga (Join Key)**: Kunci primer relasi antar-tabel tingkat rumah tangga dalam satu tahun survei.
- **Penimbang Rumah Tangga (Sampling Weight)**: Penimbang agregasi level rumah tangga untuk menghasilkan estimasi populasi representatif.
- **Rata-rata Pengeluaran Makanan Sebulan**: Total pengeluaran makanan rumah tangga sebulan (Rupiah). Konsisten penuh.
- **Total Pengeluaran Rumah Tangga Sebulan**: EXPEND = FOOD + NONFOOD. Agregat utama penentuan status kesejahteraan.
- **Pengeluaran Per Kapita Sebulan**: KAPITA = EXPEND / R301. Variabel dasar penghitungan garis kemiskinan dan desil.
- **Konsumsi Kalori Per Kapita Sehari**: Asupan energi harian per orang (Kkal). Standar kecukupan WNPG: 2.100 kkal.
- **Konsumsi Protein Per Kapita Sehari**: Asupan protein harian per orang (Gram). Standar kecukupan WNPG: 57 gram.
- **Jumlah Anggota Rumah Tangga (Ukuran RT)**: Jumlah seluruh ART yang biasanya tinggal di rumah tangga tersebut.
- **Kerawanan Pangan FIES (8 Indikator)**: Pertanyaan terstandar FAO 100% sama (1=Ya, 2=Tidak). Nomor variabel berpindah blok dari Blok XV/XVI (2019-2020) ke Blok XVII (2021-2023).
- **Bantuan Sosial PKH (Program Keluarga Harapan)**: Penerima bantuan PKH. Nomor variabel berpindah blok dari Blok XII ke Blok XXII mulai SUSENAS 2021.
- **Bantuan Pangan Non Tunai (BPNT / Sembako)**: Bansos pangan/kartu sembako. Nomor variabel berpindah blok ke Blok XXII mulai 2021.
- **Bantuan Tunai BBM (BLT BBM)**: Program baru kompensasi penyesuaian harga BBM nasional, mulai dicatat pada SUSENAS 2022/2023.
- **Status Kepemilikan Bangunan Tempat Tinggal**: 1 = Milik sendiri, 2 = Kontrak/sewa, 3 = Bebas sewa, 4 = Dinas. Blok berpindah dari XVII ke XVIII pada 2021.
