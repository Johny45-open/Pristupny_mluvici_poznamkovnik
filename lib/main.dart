import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'note.dart';
import 'tts_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mluvící poznámkovník',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
                  label: 'Poznámka: ${note.content}, vytvořeno ${DateFormat('HH:mm').format(note.createdAt)}, stav: ${note.isCompleted ? 'splněno' : 'nesplněno'}',
                  child: CheckboxListTile(
                    title: Text(note.content),
                    subtitle: Text(DateFormat('HH:mm, dd.MM.yyyy').format(note.createdAt)),
                    value: note.isCompleted,
                    onChanged: (value) => _toggleNoteCompletion(index),
                    secondary: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => _ttsService.speak('${note.content}, vytvořeno ${DateFormat('HH:mm').format(note.createdAt)}'),
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
