import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Nastavení aplikace.
///
/// Hodnoty se vedou v paměti (nahý přístup přes [instance]) a
/// asynchronně šetří do trvalého úložiště, aby přežily restart aplikace.
class AppSettings {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _keyScreenReaderAnnouncements =
      'screenReaderAnnouncements';

  bool _useScreenReaderAnnouncements = false;

  /// Je zapnuto „Hlášení přes čtečku obrazovky“.
  /// Když je zapnuto a čtečka obrazovky běží, hlasové hlášky
  /// aplikace se předávají čtečce místo vestavěného hlasu.
  bool get useScreenReaderAnnouncements => _useScreenReaderAnnouncements;

  void setUseScreenReaderAnnouncements(bool value) {
    _useScreenReaderAnnouncements = value;
    unawaited(_persist());
  }

  /// Načte nastavení z trvalého úložiště (volá se při startu aplikace).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useScreenReaderAnnouncements =
          prefs.getBool(_keyScreenReaderAnnouncements) ?? false;
    } catch (_) {
      // Úložiště není k dispozici (např. ve testech),
      // zůstává hodnota v paměti.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _keyScreenReaderAnnouncements,
        _useScreenReaderAnnouncements,
      );
    } catch (_) {
      // Uložit se nepodařilo, nastavení zůstává alespoň v paměti.
    }
  }
}
