import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mluvici_pristupny_poznamkovnik/main.dart';

void main() {
  const MethodChannel ttsChannel = MethodChannel('flutter_tts');
  final List<String> spoken = [];

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
}
