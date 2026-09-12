import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppFeedback {
  AppFeedback._();

  /// Menampilkan SnackBar placeholder untuk fitur yang belum diimplementasikan.
  static void showFeatureNotice(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(AppConstants.featureInDevelopmentMessage),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

