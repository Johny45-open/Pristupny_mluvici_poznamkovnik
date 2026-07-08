class Note {
  final String id;
  final String content;
  bool isCompleted;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.content,
    this.isCompleted = false,
    required this.createdAt,
  });
}
