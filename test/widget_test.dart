import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mluvici_pristupny_poznamkovnik/app_settings.dart';
import 'package:mluvici_pristupny_poznamkovnik/main.dart';
import 'package:mluvici_pristupny_poznamkovnik/settings_screen.dart';

void main() {
  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  const MethodChannel a11yChannel =
      MethodChannel('com.example.mluvici_pristupny_poznamkovnik/accessibility');
  final List<String> spoken = [];
  /// Hlášky předané čtečce obrazovky (metoda announce).
  final List<String> announced = [];

  /// Po každém testu vrací nastavení do původního stavu,
  /// aby se nešířilo mezi testy.
  tearDown(() {
    AppSettings.instance.setUseScreenReaderAnnouncements(false);
  });

  /// Nahradí TTS kanál falešnou verzí a zachytí všechna čtená hlášení.
  Future<void> mockTts(WidgetTester tester) async {
    spoken.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      ttsChannel,
      (MethodCall call) async {
        if (call.method == 'speak') {
          spoken.add(call.arguments as String);
        }
        return 1;
      },
    );
  }

  /// Nahradí kanál přístupnosti falešnou verzí.
  /// [screenReaderActive] rozhoduje, zda čtečka obrazovky „běží“,
  /// [announceSucceeds] zda předání hlášky na ni dopadne.
  void mockAccessibility(
    WidgetTester tester, {
    required bool screenReaderActive,
    bool announceSucceeds = true,
  }) {
    announced.clear();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      a11yChannel,
      (MethodCall call) async {
        if (call.method == 'screenReaderActive') return screenReaderActive;
        if (call.method == 'announce') {
          final args = call.arguments as Map<Object?, Object?>;
          announced.add(args['text'] as String);
          return announceSucceeds;
        }
        return null;
      },
    );
  }

  /// Zadeje a přidá novou poznámku přes existující UI.
  Future<void> addNote(WidgetTester tester, String content) async {
    await tester
        .enterText(find.widgetWithText(TextField, 'Nová poznámka'), content);
    await tester.tap(find.byTooltip('Přidat poznámku'));
    await tester.pump();
  }

  test('countOccurrences počítá výskyty bez ohledu na velikost písmen', () {
    expect(countOccurrences('Kolo KOLE kolo', 'kolo'), 2);
    expect(countOccurrences('kolé KOLÉ kola', 'kolé'), 2);
    expect(countOccurrences('xy xyxy', 'xy'), 3);
    expect(countOccurrences('Kolo KOLE kolo', 'lole'), 0);
    expect(countOccurrences('x', 'x'), 1);
    expect(countOccurrences('libovolný text', ''), 0);
  });

  test('czechNoun vrací správný tvar podle počtu', () {
    expect(czechNoun(1, 'výskyt', 'výskyty', 'výskytů'), 'výskyt');
    expect(czechNoun(2, 'výskyt', 'výskyty', 'výskytů'), 'výskyty');
    expect(czechNoun(4, 'výskyt', 'výskyty', 'výskytů'), 'výskyty');
    expect(czechNoun(5, 'výskyt', 'výskyty', 'výskytů'), 'výskytů');
    expect(czechNoun(7, 'výskyt', 'výskyty', 'výskytů'), 'výskytů');
  });

  testWidgets('Přidá a zobrazí novou poznámku a nahlas to oznámí',
      (WidgetTester tester) async {
    await mockTts(tester);
    await tester.pumpWidget(const MyApp());

    await addNote(tester, 'Koupit koláčky');

    expect(find.text('Koupit koláčky'), findsOneWidget);
    expect(
      spoken.join(' | '),
      contains('Poznámka přidána: Koupit koláčky'),
    );
  });

  testWidgets('Hledání najde poznámku, ohlásí místo a počet výskytů',
      (WidgetTester tester) async {
    await mockTts(tester);
    await tester.pumpWidget(const MyApp());

    await addNote(tester, 'Koupit koláčky a mléko');
    await addNote(tester, 'Láhev na vodu pro kino');

    await tester.enterText(find.widgetWithText(TextField, 'Hledat'), 'ko');
    await tester.tap(find.byTooltip('Hledat'));
    await tester.pump();

    // Zobrazí se jen poznámka, která výraz obsahuje.
    expect(find.text('Koupit koláčky a mléko'), findsOneWidget);
    expect(find.text('Láhev na vodu pro kino'), findsNothing);
    expect(find.text('Zrušit'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hledat'), findsNothing);

    // Souhrn je vidět a nahlas čtená forma říká, kde a kolikrát.
    // (Ko ve Koupit, koláčky a mléko.)
    expect(
      find.text('Nalezeno: 1 poznámka, celkem 3 výskyty.'),
      findsOneWidget,
    );
    expect(
      spoken.join(' | '),
      contains('Výraz ko byl nalezen v 1 poznámce, celkem 3 výskyty.'),
    );

    // Sémantický popisek zná svou pozici i počet výskytů v té poznámce.
    // Pohneme se nahoru semantickým stromem, dokud nenajdeme uzel,
    // který tenhle popisek drží.
    var node = tester.getSemantics(find.text('Koupit koláčky a mléko'));
    while (node.parent != null && !node.label.contains('Výsledek 1 z 1')) {
      node = node.parent!;
    }
    expect(node.label, contains('Výsledek 1 z 1'));
    expect(node.label, contains('vyskytuje 3x'));
    expect(node.label, contains('Poznámka: Koupit koláčky a mléko'));

    // Po zrušení hledání se vrátí celý seznam.
    await tester.tap(find.text('Zrušit'));
    await tester.pump();

    expect(find.text('Koupit koláčky a mléko'), findsOneWidget);
    expect(find.text('Láhev na vodu pro kino'), findsOneWidget);
    expect(
      spoken.join(' | '),
      contains('Vyhledávání zrušeno, zobrazuji všechny poznámky.'),
    );
  });

  testWidgets('Prázdný výsledek hledání se čte a dá se zrušit',
      (WidgetTester tester) async {
    await mockTts(tester);
    await tester.pumpWidget(const MyApp());

    await addNote(tester, 'Káva se mlékem');

    await tester.enterText(find.widgetWithText(TextField, 'Hledat'), 'čokoláda');
    await tester.tap(find.byTooltip('Hledat'));
    await tester.pump();

    expect(find.text('Káva se mlékem'), findsNothing);
    // Hláška sedí dvakrát: v souhrnu nad seznamem a ve středovém prázdném stavu.
    expect(
      find.text('Výraz «čokoláda» nebyl nalezen v žádné poznámce.'),
      findsNWidgets(2),
    );
    expect(
      spoken.join(' | '),
      contains('Výraz čokoláda nebyl nalezen v žádné poznámce.'),
    );

    await tester.tap(find.text('Zrušit'));
    await tester.pump();
    expect(find.text('Káva se mlékem'), findsOneWidget);
  });

  testWidgets('Zapnuta čtečka: hláška jde čtečce obrazovky, ne TTS',
      (WidgetTester tester) async {
    await mockTts(tester);
    mockAccessibility(tester, screenReaderActive: true);
    AppSettings.instance.setUseScreenReaderAnnouncements(true);

    await tester.pumpWidget(const MyApp());
    await addNote(tester, 'Zpráva pro čtečku');

    expect(
      announced,
      contains('Poznámka přidána: Zpráva pro čtečku'),
    );
    expect(
      spoken,
      isNot(contains('Poznámka přidána: Zpráva pro čtečku')),
    );
  });

  testWidgets('Zapnuta čtečka, ale neběží: hláška je čtená vestsaveným hlasem',
      (WidgetTester tester) async {
    await mockTts(tester);
    mockAccessibility(tester, screenReaderActive: false);
    AppSettings.instance.setUseScreenReaderAnnouncements(true);

    await tester.pumpWidget(const MyApp());
    await addNote(tester, 'Zpět na hlas');

    expect(announced, isEmpty);
    expect(spoken, contains('Poznámka přidána: Zpět na hlas'));
  });

  testWidgets('Předání čtečce selže: hláška je čtená vestsaveným hlasem',
      (WidgetTester tester) async {
    await mockTts(tester);
    mockAccessibility(
      tester,
      screenReaderActive: true,
      announceSucceeds: false,
    );
    AppSettings.instance.setUseScreenReaderAnnouncements(true);

    await tester.pumpWidget(const MyApp());
    await addNote(tester, 'Selhalo odeslání');

    expect(announced, contains('Poznámka přidána: Selhalo odeslání'));
    expect(spoken, contains('Poznámka přidána: Selhalo odeslání'));
  });

  testWidgets('Přepínač v nastavení zapne a vypne hlášení čtečkou',
      (WidgetTester tester) async {
    await mockTts(tester);
    mockAccessibility(tester, screenReaderActive: false);
    AppSettings.instance.setUseScreenReaderAnnouncements(false);

    await tester.pumpWidget(MaterialApp(home: const SettingsScreen()));

    final switchFinder = find.byType(Switch);
    expect(AppSettings.instance.useScreenReaderAnnouncements, isFalse);
    expect(find.text('Nastavení'), findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pump();
    expect(AppSettings.instance.useScreenReaderAnnouncements, isTrue);
    expect(
      spoken.join(' | '),
      contains('Odesílání hlášek přes čtečku obrazovky zapnuto.'),
    );

    await tester.tap(switchFinder);
    await tester.pump();
    expect(AppSettings.instance.useScreenReaderAnnouncements, isFalse);
    expect(
      spoken.join(' | '),
      contains('Odesílání hlášek přes čtečku obrazovky vypnuto.'),
    );
  });
}
