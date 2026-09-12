import 'package:flutter/material.dart';

/// Notifier sederhana untuk mengatur dan menguji [ThemeMode] (System / Light / Dark).
final ValueNotifier<ThemeMode> appThemeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

