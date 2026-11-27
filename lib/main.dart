import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'announcer.dart';
import 'app_settings.dart';
import 'note.dart';
import 'settings_screen.dart';
import 'tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  runApp(const MyApp());
}

/// Vrátí počet výskytů (bez překrývání) dotazu [query] v textu [text],
/// bez ohledu na velikost písmen.
int countOccurrences(String text, String query) {
  if (query.isEmpty) return 0;
  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  var count = 0;
  var index = 0;
  while (true) {
    index = lowerText.indexOf(lowerQuery, index);
    if (index == -1) return count;
    count++;
    index += lowerQuery.length;
  }
}

/// Český tvar podstatného jména podle počtu: 1, 2–4, 5 a více.
String czechNoun(int n, String singular, String few, String many) =>
    n == 1 ? singular : (n >= 2 && n <= 4 ? few : many);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final mode = brightness == Brightness.dark ? 'tmavý' : 'světlý';
    _ttsService.speak('Přepnuto na $mode režim');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mluvící poznámkovník',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: Stack(
      children: [
        const Positioned.fill(child: NoteListScreen()),
        // Skrytá živá oblast — čtečky obrazovky (nvda, TalkBack)
        // při změně hlášení přečtou text, vizuálně se nic nezobrazí.
        Positioned(
          left: -200,
          top: -200,
          child: const Opacity(
            opacity: 0,
            child: LiveAnnouncementRegion(),
          ),
        ),
      ],
    ),
    );
  }
}

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final List<Note> _notes = [];
  final TtsService _ttsService = TtsService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  /// Poslední potvrzený dotaz. Prázdný znamená, že se nehledá
  /// a zobrazuje se celý seznam.
  String _searchQuery = '';

  bool get _searching => _searchQuery.isNotEmpty;

  /// Poznámky k zobrazení. V módu hledání jen ty, které dotaz obsahují.
  List<Note> get _matchingNotes {
    if (!_searching) return _notes;
    final query = _searchQuery.toLowerCase();
    return _notes
        .where((note) => note.content.toLowerCase().contains(query))
        .toList();
  }

  void _addNote() {
    if (_textController.text.isEmpty) return;

    setState(() {
      _notes.add(Note(
        id: DateTime.now().toString(),
        content: _textController.text,
        createdAt: DateTime.now(),
      ));
    });
    _ttsService.speak('Poznámka přidána: ${_textController.text}');
    _textController.clear();
  }

  void _toggleNoteCompletion(Note note) {
    setState(() {
      note.isCompleted = !note.isCompleted;
    });
    final status = note.isCompleted ? 'splněno' : 'nesplněno';
    _ttsService.speak('Poznámka ${note.content} je nyní $status');
  }

  /// Spustí hledání podle textu v poli pro hledání.
  void _runSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _ttsService.speak('Zadejte prosím hledaný výraz.');
      return;
    }
    setState(() {
      _searchQuery = query;
    });
    _announceSearchResults(query);
  }

  /// Ukončí hledání a vrátí zpět celý seznam poznámek.
  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _ttsService.speak('Vyhledávání zrušeno, zobrazuji všechny poznámky.');
  }

  /// Nahlas ohlásí souhrn výsledků, podobně jako Microsoft Word.
  void _announceSearchResults(String query) {
    final matches = _matchingNotes;
    if (matches.isEmpty) {
      _ttsService.speak('Výraz $query nebyl nalezen v žádné poznámce.');
      return;
    }
    final count = matches.length;
    final where = count == 1
        ? 'v 1 poznámce'
        : (count >= 2 && count <= 4 ? 've $count poznámkách' : 'v $count poznámkách');
    final totalOccurrences = matches.fold<int>(
      0,
      (sum, note) => sum + countOccurrences(note.content, query),
    );
    final occurrences =
        czechNoun(totalOccurrences, 'výskyt', 'výskyty', 'výskytů');
    _ttsService.speak(
      'Výraz $query byl nalezen $where, celkem $totalOccurrences $occurrences.',
    );
  }

  /// Jednořádkový text souhrnu, který se zobrazuje nad výsledky.
  String _resultsSummary() {
    if (_matchingNotes.isEmpty) {
      return 'Výraz «$_searchQuery» nebyl nalezen v žádné poznámce.';
    }
    final count = _matchingNotes.length;
    final totalOccurrences = _matchingNotes.fold<int>(
      0,
      (sum, note) => sum + countOccurrences(note.content, _searchQuery),
    );
    return 'Nalezeno: $count ${czechNoun(count, 'poznámka', 'poznámky', 'poznámek')}, '
        'celkem $totalOccurrences ${czechNoun(totalOccurrences, 'výskyt', 'výskyty', 'výskytů')}.';
  }

  /// Rozdělí [content] na úseky a zvýrazní výskyt hledaného výrazu.
  TextSpan _buildHighlightedSpan(BuildContext context, String content) {
    final query = _searchQuery.toLowerCase();
    final lower = content.toLowerCase();
    final highlight = TextStyle(
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.bold,
    );
    final spans = <TextSpan>[];
    var start = 0;
    var index = 0;
    while (true) {
      final found = lower.indexOf(query, index);
      if (found == -1) break;
      if (found > start) {
        spans.add(TextSpan(text: content.substring(start, found)));
      }
      spans.add(TextSpan(
        text: content.substring(found, found + query.length),
        style: highlight,
      ));
      start = found + query.length;
      index = start;
    }
    if (start < content.length) {
      spans.add(TextSpan(text: content.substring(start)));
    }
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matchingNotes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Můj poznámkovník'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Nastavení',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Nová poznámka'),
                  ),
                ),
                IconButton(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  tooltip: 'Přidat poznámku',
                ),
              ],
            ),
          ),
          // Řádek hledání / souhrnu výsledků.
          if (_searching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label: _resultsSummary(),
                      child: Text(
                        _resultsSummary(),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearSearch,
                    child: const Text('Zrušit'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _runSearch(),
                      decoration: const InputDecoration(
                        labelText: 'Hledat',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _runSearch,
                    icon: const Icon(Icons.search),
                    tooltip: 'Hledat',
                  ),
                ],
              ),
            ),
          Expanded(
            child: _searching && matches.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Výraz «$_searchQuery» nebyl nalezen v žádné poznámce.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final note = matches[index];
                      final occurrences =
                          countOccurrences(note.content, _searchQuery);
                      final position = index + 1;
                      final createdTime =
                          DateFormat('HH:mm').format(note.createdAt);
                      final statusLabel = note.isCompleted ? 'Splněno.' : 'Nesplněno, je potřeba dokončit.';
                      final label = _searching
                          ? 'Výsledek $position z ${matches.length}. '
                              'V této poznámce se hledaný výraz vyskytuje ${occurrences}x. '
                              'Poznámka: ${note.content}, vytvořeno $createdTime. '
                              '$statusLabel'
                          : 'Poznámka: ${note.content}, vytvořeno $createdTime. '
                              '$statusLabel';

                      return Semantics(
                        label: label,
                        button: true,
                        onTap: () => _toggleNoteCompletion(note),
                        child: CheckboxListTile(
                          title: _searching
                              ? Text.rich(_buildHighlightedSpan(context, note.content))
                              : Text(note.content),
                          subtitle: Text(DateFormat('HH:mm, dd.MM.yyyy').format(note.createdAt)),
                          value: note.isCompleted,
                          onChanged: (value) => _toggleNoteCompletion(note),
                          secondary: IconButton(
                            icon: const Icon(Icons.volume_up),
                            tooltip: 'Předčíst poznámku',
                            onPressed: () => _ttsService.speak('${note.content}, vytvořeno $createdTime, stav: ${note.isCompleted ? 'splněno' : 'nesplněno'}'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
