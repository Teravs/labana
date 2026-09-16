import 'dart:io';

import 'package:file_picker/file_picker.dart';

/// Kontrak abstraksi untuk pemilihan berkas database (.db) dari luar aplikasi.
abstract class ExternalFilePicker {
  /// Membuka file picker sistem (SAF pada Android) untuk memilih satu berkas database .db.
  /// Mengembalikan null jika pengguna membatalkan dialog pemilihan berkas.
  Future<File?> pickDatabaseFile();
}

/// Implementasi produksi menggunakan package file_picker dengan filter ketat berkas .db.
class AppExternalFilePicker implements ExternalFilePicker {
  const AppExternalFilePicker();

  @override
  Future<File?> pickDatabaseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selectedPath = result.files.single.path;
    if (selectedPath == null || selectedPath.isEmpty) {
      return null;
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
