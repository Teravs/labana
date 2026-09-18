import 'dart:io';

import '../../../core/constants/app_constants.dart';

/// Model representasi identitas usaha/toko (nama, slogan, dan logo kustom).
class BusinessProfile {
  final String name;
  final String tagline;
  final String? logoPath;

  const BusinessProfile({
    this.name = AppConstants.appName,
    this.tagline = AppConstants.appTagline,
    this.logoPath,
  });

  /// Menandakan apakah toko memiliki logo kustom yang berkasnya valid dan eksis di filesystem.
  bool get hasCustomLogo {
    if (logoPath == null || logoPath!.trim().isEmpty) return false;
    final file = File(logoPath!);
    return file.existsSync();
  }

  BusinessProfile copyWith({
    String? name,
    String? tagline,
    String? logoPath,
    bool clearLogo = false,
  }) {
    return BusinessProfile(
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          tagline == other.tagline &&
          logoPath == other.logoPath;

  @override
  int get hashCode => Object.hash(name, tagline, logoPath);
}

