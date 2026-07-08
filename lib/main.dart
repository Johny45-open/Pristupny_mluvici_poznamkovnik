import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';
import 'tts_service.dart';

void main() {
  runApp(const MyApp());
}

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
      home: const NoteListScreen(),
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

  void _toggleNoteCompletion(int index) {
    setState(() {
      _notes[index].isCompleted = !_notes[index].isCompleted;
    });
    final status = _notes[index].isCompleted ? 'splněno' : 'nesplněno';
    _ttsService.speak('Poznámka ${_notes[index].content} je nyní $status');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Můj poznámkovník'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
          Expanded(
            child: ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Semantics(
                  label: 'Poznámka: ${note.content}, vytvořeno ${DateFormat('HH:mm').format(note.createdAt)}. ${note.isCompleted ? 'Splněno' : 'Nesplněno, je potřeba dokončit.'}',
                  button: true,
                  onTap: () => _toggleNoteCompletion(index),
                  child: CheckboxListTile(
                    title: Text(note.content),
                    subtitle: Text(DateFormat('HH:mm, dd.MM.yyyy').format(note.createdAt)),
                    value: note.isCompleted,
                    onChanged: (value) => _toggleNoteCompletion(index),
                    secondary: IconButton(
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Předčíst poznámku',
                      onPressed: () => _ttsService.speak('${note.content}, vytvořeno ${DateFormat('HH:mm').format(note.createdAt)}, stav: ${note.isCompleted ? 'splněno' : 'nesplněno'}'),
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
