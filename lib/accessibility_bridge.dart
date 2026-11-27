import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Most na nativní Android přístupnost (MainActivity.kt):
/// detekce běžící čtečky obrazovky a předání hlásek do ní.
///
/// Na platformách jiných než Android vrací false, aby se hlášky
/// předčítaly vestavěným hlasem.
class AccessibilityBridge {
  static const MethodChannel _channel =
      MethodChannel('com.example.mluvici_pristupny_poznamkovnik/accessibility');

  bool get _isSupported => defaultTargetPlatform == TargetPlatform.android;

  /// Vrátí true, pokud na zařízení běží čtečka obrazovky
  /// (např. TalkBack). Jinde než na Androidu vždy false.
  Future<bool> screenReaderActive() =>
      _callBool('screenReaderActive');

  /// Předá hlášku [text] běžící čtečce obrazovky.
  /// Vrátí false, když předání nebylo možné
  /// (čtečka neběží, jiná platforma, chybějící plugin).
  Future<bool> announce(String text) =>
      _callBool('announce', {'text': text});

  /// Volá nativní metodu a vrací její bool výsledek.
  /// Chyby platformního spojení tlumí na false, aby se mohl
  /// nastavit vestavěný hlas.
  Future<bool> _callBool(String method, [Map<String, Object?>? arguments]) async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(method, arguments);
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
