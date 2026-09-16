/// Informasi ringkas sebuah berkas cadangan (.db) di filesystem lokal.
class BackupFileInfo {
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final DateTime createdAt;

  const BackupFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.createdAt,
  });

  /// Format ukuran berkas yang mudah dibaca pengguna (misal: "240 B", "125 KB", "3.4 MB").
  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '${kb.endsWith('.0') ? kb.substring(0, kb.length - 2) : kb} KB';
    } else {
      final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      return '${mb.endsWith('.0') ? mb.substring(0, mb.length - 2) : mb} MB';
    }
  }

  /// Format tanggal dan waktu pembuatan cadangan dalam bahasa Indonesia.
  String get formattedDate {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = createdAt.day;
    final month = months[createdAt.month];
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

/// Ringkasan isi data yang terekstraksi dari berkas database cadangan.
class BackupDataSummary {
  final int transactionCount;
  final int productCount;
  final int ingredientCount;
  final int processedIngredientCount;
  final int databaseVersion;
  final String? lastTransactionDate;

  const BackupDataSummary({
    required this.transactionCount,
    required this.productCount,
    required this.ingredientCount,
    required this.processedIngredientCount,
    required this.databaseVersion,
    this.lastTransactionDate,
  });

  /// Format tanggal transaksi terakhir jika ada.
  String get formattedLastTransactionDate {
    if (lastTransactionDate == null || lastTransactionDate!.isEmpty) {
      return 'Belum ada transaksi';
    }
    try {
      final parsed = DateTime.parse(lastTransactionDate!);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      final day = parsed.day;
      final month = months[parsed.month];
      final year = parsed.year;
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute';
    } catch (_) {
      return lastTransactionDate!;
    }
  }
}

/// Hasil validasi menyeluruh terhadap berkas cadangan sebelum pemulihan.
class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BackupDataSummary? summary;

  const BackupValidationResult.valid(this.summary)
    : isValid = true,
      errorMessage = null;

  const BackupValidationResult.invalid(this.errorMessage)
    : isValid = false,
      summary = null;
}

/// Exception yang dilempar saat terjadi kegagalan pada proses pencadangan atau pemulihan database.
class DatabaseBackupException implements Exception {
  final String message;
  final String? details;

  const DatabaseBackupException(this.message, [this.details]);

  @override
  String toString() =>
      details == null ? message : '$message (Rincian: $details)';
}
