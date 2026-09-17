import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// Kontrak abstraksi untuk pemilihan berkas database (.db) dari luar aplikasi.
abstract class ExternalFilePicker {
  /// Membuka file picker sistem (SAF pada Android) untuk memilih satu berkas database .db.
  /// Mengembalikan null jika pengguna membatalkan dialog pemilihan berkas.
  Future<File?> pickDatabaseFile();
}

/// Implementasi produksi menggunakan package file_picker dengan filter berkas .db
/// dan fallback aman untuk platform Android SAF.
class AppExternalFilePicker implements ExternalFilePicker {
  const AppExternalFilePicker();

  @override
  Future<File?> pickDatabaseFile() async {
    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        allowMultiple: false,
      );
    } on PlatformException catch (_) {
      // Pada Android tertentu, ekstensi 'db' tidak terdaftar dalam MIME map OS,
      // sehingga SAF melempar Unsupported filter error. Fallback ke FileType.any.
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
    }

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return null;
    }

    // Validasi ketat bahwa file yang dipilih berakhiran .db
    if (!selectedPath.toLowerCase().endsWith('.db')) {
      throw const FormatException(
        'Berkas yang dipilih bukan berkas database SQLite (.db).',
      );
    }

    return File(selectedPath);
  }
}

/// Implementasi tiruan (fake) untuk keperluan unit dan widget testing.
class FakeExternalFilePicker implements ExternalFilePicker {
  File? fileToReturn;
  bool wasCalled = false;

  FakeExternalFilePicker({this.fileToReturn});

  @override
  Future<File?> pickDatabaseFile() async {
    wasCalled = true;
    return fileToReturn;
  }
}
