import 'package:flutter/widgets.dart';

/// Drží aktuální hlášení pro skrytou živou oblast (live region).
///
/// Živá oblast je sémantický uzel, který čtečka obrazovky
/// (např. NVDA) přečte při změně popisku.
class Announcer extends ChangeNotifier {
  Announcer._internal();

  static final Announcer instance = Announcer._internal();

  String _text = '';

  String get text => _text;

  /// Oznámi [value] v živé oblasti.
  ///
  /// Oproti ValueNotifier se spouští i při stejném textu, takže
  /// čtečka přečte i opakování stejné hlášky.
  void announce(String value) {
    _text = value;
    notifyListeners();
  }
}

/// Skrytá živá oblast, která čtečce obrazovky oznamuje hlášení.
///
/// Vizuálně se nezobrazuje, ale sémantický uzel s live region zůstává
/// ve stromu — při změně [Announcer.text] ho čtečka přečte.
class LiveAnnouncementRegion extends StatelessWidget {
  const LiveAnnouncementRegion({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Announcer.instance,
      builder: (context, _) => Semantics(
        liveRegion: true,
        label: Announcer.instance.text,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
