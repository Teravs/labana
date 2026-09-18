# 📘 Buku Panduan Pengguna (User Guide) Labana
### *Kelola Modal, Pahami Laba — Aplikasi Manajemen HPP, Resep, Kasir & Laporan Keuangan UMKM*

---

## 📑 Daftar Isi
1. [🌟 Mengenal Labana & Konsep HPP](#1--mengenal-labana--konsep-hpp)
2. [⚙️ Kustomisasi Identitas Toko / Usaha](#2-️-kustomisasi-identitas-toko--usaha)
3. [🌾 Langkah 1: Mengelola Bahan Mentah & Harga Beli](#3--langkah-1-mengelola-bahan-mentah--harga-beli)
4. [🍲 Langkah 2: Meracik Formula Bahan Olahan (Bahan Setengah Jadi)](#4--langkah-2-meracik-formula-bahan-olahan-bahan-setengah-jadi)
5. [🏷️ Langkah 3: Membuat Menu Produk, Resep & Penetapan Harga Jual](#5-️-langkah-3-membuat-menu-produk-resep--penetapan-harga-jual)
6. [🧾 Langkah 4: Kasir Penjualan & Pencatatan Transaksi](#6-️-langkah-4-kasir-penjualan--pencatatan-transaksi)
7. [📊 Langkah 5: Membaca Dashboard & Laporan Keuangan](#7--langkah-5-membaca-dashboard--laporan-keuangan)
8. [📄 Langkah 6: Ekspor Dokumen Laporan PDF Resmi](#8--langkah-6-ekspor-dokumen-laporan-pdf-resmi)
9. [💾 Langkah 7: Pencadangan & Pemulihan Basis Data (Backup & Restore)](#9--langkah-7-pencadangan--pemulihan-basis-data-backup--restore)
10. [🗄️ Langkah 8: Pengarsipan & Retensi Data Bulanan](#10-️-langkah-8-pengarsipan--retensi-data-bulanan)
11. [💡 Tips Praktis Manajemen Keuangan UMKM](#11--tips-praktis-manajemen-keuangan-umkm)

---

## 1. 🌟 Mengenal Labana & Konsep HPP

### Apa itu Labana?
**Labana** adalah aplikasi finansial dan operasional bisnis **100% Offline-First** yang dirancang untuk pelaku UMKM (Food & Beverage, Bakery, Kedai Kopi, Katering, dan Manufaktur Skala Rumah Tangga). Seluruh data Anda disimpan secara aman di dalam perangkat tanpa membutuhkan internet atau biaya sewa server bulanan.

### Mengapa HPP (Harga Pokok Penjualan) Sangat Penting?
Banyak usaha mikro ramai pembeli namun kehabisan modal di akhir bulan karena tidak mengetahui modal riil per porsi makanan/minuman yang dijual.
- **HPP (Modal Pokok)** = Total biaya bahan mentah + bahan olahan + biaya kemasan (cup, sedotan, box) + biaya utilitas per porsi.
- **Laba Kotor (Gross Profit)** = Harga Jual - HPP per Porsi.
- **Margin Keuntungan (%)** = `(Laba / Harga Jual) x 100%`.

Labana menghitung seluruh formula di atas secara otomatis dan seketika (*live calculation*).

---

## 2. ⚙️ Kustomisasi Identitas Toko / Usaha

Anda dapat menyesuaikan nama usaha, slogan, dan logo toko yang akan tampil di Dashboard, menu aplikasi, dan dokumen cetak Laporan PDF.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Buka Menu "Pengaturan" (Ikon Gerigi di Pojok Kanan Atas) │
│ 2. Pilih menu "Profil Toko / Usaha"                         │
│ 3. Unggah Logo Toko (format PNG / JPG)                      │
│ 4. Isi Nama Toko / Usaha (Contoh: "Kopi Kenangan Senja")     │
│ 5. Isi Slogan / Tagline (Contoh: "Rasa Juara, Harga Ramah") │
│ 6. Klik "Simpan Perubahan"                                  │
└─────────────────────────────────────────────────────────────┘
```

> **Catatan:** Perubahan identitas langsung diterapkan secara reaktif di seluruh aplikasi dan dokumen laporan PDF tanpa perlu memuat ulang aplikasi.

---

## 3. 🌾 Langkah 1: Mengelola Bahan Mentah & Harga Beli

Bahan mentah adalah bahan dasar yang dibeli langsung dari pasar/distributor (misal: Biji Kopi, Gula Pasir, Susu UHT, Tepung Terigu, Cup Plastik, dsb).

### Cara Menambahkan Bahan Mentah:
1. Masuk ke menu **Bahan** pada navigasi bawah, lalu pilih tab **Bahan Mentah**.
2. Tekan tombol **+ Bahan Mentah** (atau tombol FAB bulat di kanan bawah).
3. Masukkan **Nama Bahan** (misal: *Gula Pasir*).
4. Pilih **Satuan Penggunaan di Dapur** (`gram (g)`, `kilogram (kg)`, `mililiter (ml)`, `liter (l)`, `pcs`, `pack`).
5. Masukkan **Harga Beli Terbaru** beserta jumlah belinya.
   - *Contoh Konversi Otomatis*: Anda membeli Gula Pasir 1 Karung isi 50 kg seharga Rp750.000. Cukup pilih beli per satuan `kg`, masukkan 50 kg dan total harga Rp750.000. Labana otomatis menghitung harga dasar dapur = **Rp15 / gram**.
6. Klik **Simpan Bahan**.

### Melacak Kenaikan / Fluktuasi Harga Beli:
Jika harga bahan naik di kemudian hari:
1. Buka bahan mentah yang diinginkan, pilih **Riwayat Harga**.
2. Tekan **+ Tambah Harga Baru**, masukkan harga dan tanggal berlakunya.
3. Labana akan menggunakan harga terbaru untuk kalkulasi HPP produk aktif ke depan tanpa mengubah rekaman transaksi historis yang sudah selesai.

---

## 4. 🍲 Langkah 2: Meracik Formula Bahan Olahan (Bahan Setengah Jadi)

Bahan olahan adalah racikan yang disiapkan terlebih dahulu sebelum diracik menjadi menu jadi (misal: *Simple Syrup (Gula Cair), Biang Teh Melati, Espresso Base, Selai Nanas, Saus Racik*).

### Cara Membuat Bahan Olahan:
1. Masuk ke menu **Bahan**, pilih tab **Bahan Olahan**.
2. Tekan tombol **+ Bahan Olahan**.
3. Masukkan **Nama Bahan Olahan** (misal: *Simple Syrup Gula Pasir*).
4. Masukkan **Total Hasil Jadi / Yield Batch** (misal: *1.000 ml*).
5. Tambahkan Komponen Penyusun:
   - **Bahan Mentah**: Pilih Gula Pasir (misal: 1.000 gram = Rp15.000) dan Air Mineral (1.000 ml = Rp2.000).
   - **Bahan Olahan Lain (Nested)**: Anda juga dapat memasukkan bahan olahan lain ke dalam racikan ini.
   - **Biaya Lainnya / Operasional**: Masukkan biaya gas, listrik, atau tenaga kerja per batch pembuatan (misal: Gas & Listrik = Rp3.000).
6. **Live Preview Modal**: Sistem langsung menghitung total biaya batch (Rp20.000) dan biaya per unit jadi (**Rp20 / ml**).
7. Klik **Simpan Bahan Olahan**.

---

## 5. 🏷️ Langkah 3: Membuat Menu Produk, Resep & Penetapan Harga Jual

Setelah bahan mentah dan olahan siap, saatnya membuat produk jadi yang siap dijual ke pelanggan.

### Cara Membuat Produk & Formula Resep:
1. Masuk ke menu **Produk / Resep** pada navigasi bawah.
2. Tekan tombol **+ Tambah Produk**.
3. Masukkan **Nama Menu** (misal: *Es Kopi Susu Aren 16oz*).
4. Susun Komposisi Resep per Porsi:
   - **Bahan Olahan**: Simple Syrup 20 ml (Rp400), Espresso Base 30 ml (Rp1.500).
   - **Bahan Mentah**: Susu UHT 120 ml (Rp2.400), Es Batu 50 gram (Rp200).
   - **Biaya Lainnya (Kemasan)**: Cup 16oz + Tutup Dome + Sedotan Steril (Rp750).
5. **Kalkulator HPP Live**: Modal HPP per cup otomatis terhitung: **Rp5.250 / cup**.
6. **Tentukan Harga Jual**:
   - Ketikkan rencana harga jual, misal: **Rp18.000**.
   - Labana langsung menampilkan:
     - Estimasi Laba Kotor per Porsi = **Rp12.750**
     - Margin Keuntungan = **70.8%**
7. Klik **Simpan Produk**.

---

## 6. 🧾 Langkah 4: Kasir Penjualan & Pencatatan Transaksi

Fitur Kasir digunakan untuk mencatat penjualan harian secara cepat dan akurat.

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Buka Tab "Penjualan" -> Tekan "+ Catat Penjualan"        │
│ 2. Pilih Produk yang dipesan dan tentukan jumlahnya         │
│ 3. Lihat Ringkasan: Total Omzet, Modal HPP, dan Total Laba │
│ 4. Pilih Metode Pembayaran (Tunai / Transfer / QRIS)        │
│ 5. Isi Catatan (Opsional, misal: "Meja 05 / Takeaway")      │
│ 6. Tekan "Simpan Transaksi"                                │
└─────────────────────────────────────────────────────────────┘
```

### 🔒 Jaminan Akurasi Abadi (*Historical Cost Snapshot*):
Saat Anda menyimpan transaksi, Labana mengunci (*snapshot*) harga jual dan HPP detik itu juga ke dalam transaksi.
> **Penting:** Jika minggu depan harga susu atau biji kopi naik, keuntungan transaksi hari ini **TIDAK AKAN BERUBAH** karena tersimpan permanen sesuai kondisi saat transaksi terjadi.

---

## 7. 📊 Langkah 5: Membaca Dashboard & Laporan Keuangan

### 1. Dashboard Hari Ini (Home)
- **4 Kartu Finansial**: Memantau Omzet, Modal Terpakai (HPP), Laba Bersih, dan Jumlah Transaksi hari ini secara instan.
- **Produk Terlaris (*Top Selling*)**: Menu yang paling banyak dibeli pelanggan hari ini.
- **Produk Paling Menguntungkan (*Highest Profit*)**: Menu penyumbang keuntungan terbesar hari ini.
- **Aksi Cepat (*Quick Actions*)**: Akses 1 klik untuk tambah penjualan, tambah bahan, atau buat produk.

### 2. Tab Laporan Keuangan (Reports)
Pilih salah satu dari 3 mode periode:
- **Harian**: Evaluasi penjualan per tanggal tertentu.
- **Mingguan**: Evaluasi tren omzet dan laba selama 7 hari berturut-turut.
- **Bulanan**: Evaluasi performa keuangan 1 bulan kalender penuh.

---

## 8. 📄 Langkah 6: Ekspor Dokumen Laporan PDF Resmi

Laporan keuangan dapat dicetak atau dibagikan ke pihak luar (mitra, investor, akuntan, atau disimpan sebagai arsip).

1. Buka menu **Laporan**, lalu pilih periode yang ingin dicetak (misal: *Bulan September 2026*).
2. Tekan tombol **Ekspor PDF** di pojok kanan atas.
3. Dokumen PDF standar **A4** akan dibuat secara instan:
   - **Header Utama**: Logo toko kustom, Nama Usaha (huruf besar tebal), dan Slogan usaha.
   - **Ringkasan Finansial**: Total Omzet, Modal HPP, Laba Bersih, Margin %, dan Rata-rata Nilai Transaksi.
   - **Daftar Produk Terlaris & Tabel Harian**: Rincian penjualan harian dan metode pembayaran.
   - **Footer Dokumen**: Identitas toko dan penomoran halaman dinamis (*"Halaman 1 dari 2"*).
4. Layar berbagi sistem (*Share Sheet*) akan terbuka otomatis untuk mengirim PDF via **WhatsApp**, **Email**, **Telegram**, atau **Google Drive**.

---

## 9. 💾 Langkah 7: Pencadangan & Pemulihan Basis Data (Backup & Restore)

Karena Labana bekerja 100% offline di perangkat Anda, sangat disarankan untuk melakukan pencadangan berkala.

### Membuat Cadangan Data (Backup):
1. Buka menu **Pengaturan** -> pilih **Cadangan & Pemulihan Basis Data**.
2. Tekan tombol **Cadangkan Sekarang**.
3. Sistem akan membuat berkas `.db` berisi seluruh data usaha Anda.
4. Pada daftar berkas cadangan:
   - Tekan ikon **Download** untuk menyimpan file langsung ke folder `Downloads` perangkat.
   - Tekan ikon **Share** untuk mengirim cadangan ke Google Drive, Email, atau WhatsApp.

### Memulihkan Data (Restore):
Jika Anda berganti ponsel atau ingin mengembalikan data lama:
1. Masuk ke halaman **Cadangan & Pemulihan Basis Data**.
2. Pilih berkas dari daftar cadangan lokal ATAU tekan **Pilih Berkas Cadangan dari Luar** untuk memilih berkas `.db` dari penyimpanan HP.
3. Periksa rincian data (tanggal cadangan, jumlah transaksi, jumlah resep).
4. Konfirmasi pemulihan. Sistem menerapkan proteksi integritas multi-lapis untuk memastikan file tidak rusak sebelum data diterapkan.

---

## 10. 🗄️ Langkah 8: Pengarsipan & Retensi Data Bulanan

Jika data penjualan sudah bertahun-tahun dan Anda ingin mengosongkan memori HP:

1. Buka menu **Pengaturan** -> pilih **Retensi & Pengarsipan Data**.
2. Anda akan melihat daftar arsip penjualan per bulan beserta status unduhannya.
3. **Syarat Aman**: Tombol Hapus hanya akan aktif jika laporan PDF bulan tersebut **sudah diunduh** terlebih dahulu sebagai bukti arsip.
4. **Proteksi Master Data 100%**:
   > Penghapusan retensi **HANYA** menghapus riwayat transaksi penjualan bulan bersangkutan. Seluruh data master **Resep, Produk, Bahan Mentah, dan Bahan Olahan TETAP UTUH dan TIDAK DIHAPUS**.

---

## 11. 💡 Tips Praktis Manajemen Keuangan UMKM

1. **Rutin Update Harga Bahan Baku**: Setiap kali belanja grosir dan ada kenaikan harga, segera tambahkan harga baru di master bahan mentah agar perhitungan HPP menu baru selalu akurat.
2. **Jangan Lupakan Biaya Kemasan & Listrik**: Masukkan biaya plastik, sedotan, label stiker, dan estimasi gas/listrik ke dalam formula resep agar modal tidak bocor halus.
3. **Backup Seminggu Sekali**: Kirim berkas cadangan `.db` ke WhatsApp diri sendiri atau simpan di Google Drive untuk keamanan jangka panjang.
4. **Pantau Menu Highest Profit vs Top Selling**: Menu yang paling laris belum tentu yang paling menghasilkan uang. Gunakan data analitik Labana untuk mempromosikan menu dengan margin laba terbaik!

---

*Labana — Kelola Modal, Pahami Laba. Sukses selalu untuk bisnis Anda!* 🚀

