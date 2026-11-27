import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'accessibility_bridge.dart';
import 'announcer.dart';
import 'app_settings.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final AccessibilityBridge _accessibility = AccessibilityBridge();

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("cs-CZ");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
  }

  /// Řekne [text] vestavěným hlasem, popřípadě ho předá běžící
  /// čtečce obrazovky (např. TalkBack), pokud je v nastavení
  /// zapnuto „Hlášení přes čtečku obrazovky“.
  ///
  /// Pokud se hlášce nepodaří doručit čtečce (neběží nebo
  /// předání selže), zůstává vestavěný hlas.
  Future<void> speak(String text) async {
    if (AppSettings.instance.useScreenReaderAnnouncements) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          if (await _accessibility.screenReaderActive()) {
            final delivered = await _accessibility.announce(text);
            if (delivered) return;
          }
          // Neshlo to, čte ji vestsavený hlas.
          break;
        case TargetPlatform.windows:
          // NVDA a další čtečky přečtou změnu živé oblasti.
          // Vestavěný hlas se tady záměrně nepoužívá,
          // aby se dvě hlasy nepřekrývaly.
          Announcer.instance.announce(text);
          return;
        default:
          break;
      }
    }
    await _flutterTts.speak(text);
  }
}
