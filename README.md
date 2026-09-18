<p align="center">
  <img src="assets/logo.png" alt="Labana Logo" width="160" />
</p>

<p align="center">
  <strong>Kelola Modal, Pahami Laba.</strong><br>
  Aplikasi Manajemen Biaya Produksi (HPP), Formula Resep, Transaksi Kasir, dan Laporan Keuangan UMKM 100% Offline-First.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11.1+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11.1+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Database-SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Architecture-Offline--First-006C4C?style=for-the-badge" alt="Offline-First" />
  <img src="https://img.shields.io/badge/Tests-306%20Passed-brightgreen?style=for-the-badge" alt="Tests Passed" />
</p>

---

## 🌟 Tentang Labana

**Labana** adalah aplikasi finansial dan manajemen operasional bisnis mikro yang dirancang khusus untuk UMKM—khususnya sektor **Food & Beverage (F&B), Bakery, Kedai Kopi, Katering, dan Manufaktur Skala Rumahan**.

Tantangan terbesar pelaku usaha kecil adalah menghitung modal per porsi (**Harga Pokok Penjualan / HPP**) secara akurat ketika harga bahan baku di pasar terus berfluktuasi. Labana hadir untuk menyelesaikan masalah tersebut secara otomatis, presisi, dan sepenuhnya mandiri tanpa bergantung pada internet atau biaya sewa server bulanan.

---

## ✨ Fitur Utama

### 1. 📊 Dashboard Analitik Real-Time
- **Ringkasan Keuangan Hari Ini**: Memantau Omzet, Total Modal Terpakai (HPP), Estimasi Laba Bersih, dan Persentase Margin Keuntungan secara seketika.
- **Produk Terlaris (*Top Selling*)**: Deteksi otomatis menu dengan volume transaksi tertinggi.
- **Produk Paling Menguntungkan (*Highest Profit*)**: Deteksi menu penyumbang laba kotor terbesar.
- **Aksi Cepat (*Quick Actions*)**: Jalan pintas untuk mencatat transaksi, menambah bahan, atau meracik produk baru.

### 2. 🌾 Manajemen Bahan Mentah & Riwayat Fluktuasi Harga
- Mendukung berbagai satuan dasar: `gram (g)`, `kilogram (kg)`, `mililiter (ml)`, `liter (l)`, `pcs`, dan `pack`.
- **Konversi Multi-Satuan Otomatis**: Belanja dalam karton/pack langsung dikonversi ke satuan resep dapur (misal: 1 pack = 500 gram).
- **Pelacak Fluktuasi Harga (*Price History*)**: Mencatat sejarah perubahan harga beli dari waktu ke waktu beserta tanggal efektifnya.

### 3. 🍲 Formula Bahan Olahan (*Semi-Finished Prep*)
- Khusus racikan bahan setengah jadi (misal: *Simple Syrup, Biang Teh, Saus Racik, Adonan Roti*).
- **Nested Recipe**: Bahan olahan dapat dijadikan komponen di dalam bahan olahan lain.
- **Biaya Operasional Batch**: Mendukung penambahan biaya listrik, gas, atau tenaga kerja per proses racik.
- **Kalkulasi Yield Output**: Biaya per unit hasil jadi terhitung otomatis hingga takaran desimal.
- **Circular Dependency Guard**: Mencegah kesalahan logika resep yang saling merujuk.

### 4. 🏷️ Formula Resep Menu & Live Costing HPP
- Menggabungkan Bahan Mentah + Bahan Olahan + Biaya Kemasan (cup, sedotan, box, kantong).
- **Live Costing Preview**: Modal HPP per porsi langsung terhitung otomatis saat takaran diketik.
- **Kalkulator Margin Real-Time**: Melihat simulasi margin laba sebelum menu disimpan.
- **Proteksi Integritas Data**: Mencegah penghapusan bahan yang masih aktif digunakan pada resep menu.

### 5. 🧾 Kasir Penjualan & Historical Cost Snapshot
- **Multi-Product Checkout**: Transaksi kasir cepat untuk banyak produk sekaligus.
- **Historical Cost Snapshot (Akurasi Finansial Abadi)**:
  Sistem membekukan harga jual dan modal HPP pada detik transaksi dibuat. Jika di masa depan harga bahan naik, **pembukuan penjualan masa lalu tetap akurat 100%**.
- Riwayat transaksi detail dan pembatalan transaksi dengan konfirmasi pengaman.

### 6. 📈 Laporan Finansial Multi-Periode
- 3 Mode Periode Fleksibel: **Harian**, **Mingguan (7 hari)**, dan **Bulanan (kalender riil)**.
- Rincian Finansial: Total Omzet, Total Modal, Laba Bersih, Margin %, dan Kontribusi Laba per Produk.
- Navigasi rentang waktu yang mulus untuk memeriksa pembukuan masa lalu.

### 7. 📄 Generator Laporan PDF Standar A4 & Berbagi
- Ekspor laporan satu kali klik ke dokumen **PDF standar A4**.
- Tata letak profesional dengan palet warna elegan (Emerald & Gold) dan nomor halaman dinamis (*"Halaman X dari Y"*).
- **Berbagi Cepat**: Terintegrasi langsung dengan *System Share Sheet* (WhatsApp, Email, Telegram, Google Drive).
- **100% Offline**: PDF dibuat langsung di perangkat tanpa API atau server eksternal.

### 8. 💾 Cadangan & Pemulihan Database Mandiri (*Backup & Restore*)
- **Pencadangan Instan (`.db`)**: Seluruh data bisnis dapat diekspor menjadi berkas SQLite tunggal.
- **Pemulihan Aman (*Atomic Restore*)**: Mendukung pemilihan berkas lokal maupun eksternal via Android Storage Access Framework (SAF).
- **Rollback Guard**: Validasi integritas multi-lapis (16-byte magic header, integrity check, foreign key check). Jika file rusak, sistem otomatis membatalkan pemulihan sehingga data lama tidak hilang.

### 9. 🎨 Modern UI & Kestabilan Layout
- Desain **Material 3** yang bersih dan elegan dengan tipografi *Plus Jakarta Sans*.
- **Dukungan Tema Ganda**: Mode Terang (*Light Mode*) & Mode Gelap (*Dark Mode*).
- **Ultra-Responsif**: Dioptimalkan untuk berbagai dimensi layar (dari lebar sempit 320px hingga tablet) tanpa risiko *layout overflow*.

---

## 🏗️ Arsitektur & Teknologi

Labana dibangun dengan prinsip arsitektur modular, bersih, dan bebas ketergantungan eksternal:

```
lib/
├── core/                         # Utilitas umum, tema, konstanta, dan komponen UI bersama
│   ├── constants/                # Nama aplikasi, versi, path aset
│   ├── database/                 # SQLite helper & skema migrasi tabel
│   ├── theme/                    # Material 3 Light & Dark mode, tipografi
│   ├── utils/                    # Unit converter, formatters mata uang & tanggal
│   └── widgets/                  # Empty state, section title, stat cards
├── features/                     # Fitur modular (Clean / Feature-First Pattern)
│   ├── backup/                   # Layanan backup, restore, SAF external picker
│   ├── home/                     # Dashboard analitik riil
│   ├── ingredients/              # Master bahan mentah & riwayat harga
│   ├── processed_ingredients/    # Resep bahan olahan (nested prep)
│   ├── products/                 # Produk jadi, formula resep, engine HPP
│   ├── reports/                  # Laporan multi-periode & PDF generator murni
│   ├── sales/                    # Transaksi kasir POS & snapshot historis
│   ├── settings/                 # Konfigurasi tema & informasi sistem
│   └── shell/                    # Bottom navigation bar (5 cabang navigasi)
├── routes/                       # Declarative routing (GoRouter)
└── main.dart                     # Entry point & global state reload notifier
```

### Tech Stack:
- **Framework**: [Flutter](https://flutter.dev) & [Dart](https://dart.dev)
- **Database Engine**: [SQLite](https://sqlite.org) (`sqflite` & `sqflite_common_ffi`)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **PDF Engine**: [pdf](https://pub.dev/packages/pdf) (Pure Dart Vector PDF)
- **File System & Sharing**: `path_provider`, `share_plus`, `file_picker`
- **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (*Plus Jakarta Sans*)

---

## 🚀 Memulai Proyek (Getting Started)

### Prasyarat
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi 3.11.1 atau lebih baru)
- Android Studio / VS Code dengan ekstensi Flutter & Dart
- Android SDK (API level 21+)

### Langkah Instalasi

1. **Clone repository**:
   ```bash
   git clone https://github.com/Teravs/labana.git
   cd labana
   ```

2. **Pasang seluruh dependensi**:
   ```bash
   flutter pub get
   ```

3. **Jalankan aplikasi di perangkat / emulator**:
   ```bash
   flutter run
   ```

---

## 📖 Buku Panduan Pengguna (User Guide)

Untuk panduan alur operasional, cara perhitungan HPP, peracikan resep, kasir, ekspor PDF, hingga manajemen cadangan data, silakan baca dokumentasi lengkap di:
👉 **[Buku Panduan Pengguna (PANDUAN_PENGGUNA.md)](PANDUAN_PENGGUNA.md)**

---

## 🧪 Pengujian & Kualitas Kode

Proyek ini dilengkapi dengan cakupan pengujian menyeluruh (Unit Test, Calculation Test, Widget Test, dan End-to-End Integration Test):

```bash
# 1. Jalankan pemformatan kode
dart format .

# 2. Jalankan analisis statis
flutter analyze

# 3. Jalankan seluruh test suite (306 pengujian)
flutter test --reporter expanded
```

Status Pengujian: **306 / 306 Tests Passed (100% Lulus)**.

---

## 📄 Lisensi

Hak Cipta © 2026 **Labana**. Seluruh hak cipta dilindungi undang-undang.
Dibuat untuk memberdayakan UMKM dalam mengelola modal usaha dan meraih keuntungan yang sehat.
