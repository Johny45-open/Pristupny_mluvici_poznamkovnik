import 'package:flutter/material.dart';

import 'accessibility_bridge.dart';
import 'app_settings.dart';
import 'tts_service.dart';

/// Obrazovka nastavení aplikace.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _ttsService = TtsService();
  final AccessibilityBridge _accessibility = AccessibilityBridge();

  /// Stav běžícího screen readeru; null = zatím se zjistuje.
  bool? _screenReaderActive;

  bool get _useScreenReader =>
      AppSettings.instance.useScreenReaderAnnouncements;

  @override
  void initState() {
    super.initState();
    _refreshScreenReaderStatus();
  }

  Future<void> _refreshScreenReaderStatus() async {
    final active = await _accessibility.screenReaderActive();
    if (mounted) {
      setState(() => _screenReaderActive = active);
    }
  }

  void _onScreenReaderAnnouncementsChanged(bool value) {
    AppSettings.instance.setUseScreenReaderAnnouncements(value);
    setState(() {});
    _ttsService.speak(
      value
          ? 'Odesílání hlášek přes čtečku obrazovky zapnuto.'
          : 'Odesílání hlášek přes čtečku obrazovky vypnuto.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenReaderActive = _screenReaderActive ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Nastavení')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.accessibility),
            title: const Text('Hlášení přes čtečku obrazovky'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pokud běží čtečka obrazovky (např. TalkBack), '
                  'hlasové hlášky aplikace se předají na ni místo '
                  'vestavěného hlasu. Bez běžící čtečky hlášky čte '
                  'vestavěný hlas.',
                ),
                const SizedBox(height: 4),
                Text(
                  screenReaderActive
                      ? 'Čtečka obrazovky: aktivní'
                      : 'Čtečka obrazovky: neaktivní',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            value: _useScreenReader,
            onChanged: _onScreenReaderAnnouncementsChanged,
          ),
        ],
      ),
    );
  }
}
