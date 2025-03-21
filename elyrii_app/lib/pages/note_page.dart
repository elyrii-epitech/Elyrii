import 'package:flutter/material.dart';

class Note {
  String id;
  String title;
  String content;
  DateTime dateCreated;
  DateTime dateModified;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.dateCreated,
    required this.dateModified,
  });
}

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  List<Note> notes = [];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notes',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6E3EFF),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _createNewNote(context),
          ),
        ],
      ),
      body: notes.isEmpty
          ? _buildEmptyState()
          : _buildNotesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune note',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return ListView.builder(
      itemCount: notes.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final note = notes[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            title: Text(
              note.title.isEmpty ? 'Sans titre' : note.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDate(note.dateModified),
              style: TextStyle(color: Colors.grey[600]),
            ),
            onTap: () => _editNote(context, note),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _createNewNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          onSave: (title, content) {
            setState(() {
              notes.add(Note(
                id: DateTime.now().toString(),
                title: title,
                content: content,
                dateCreated: DateTime.now(),
                dateModified: DateTime.now(),
              ));
            });
          },
        ),
      ),
    );
  }

  void _editNote(BuildContext context, Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          initialTitle: note.title,
          initialContent: note.content,
          onSave: (title, content) {
            setState(() {
              final index = notes.indexWhere((n) => n.id == note.id);
              notes[index] = Note(
                id: note.id,
                title: title,
                content: content,
                dateCreated: note.dateCreated,
                dateModified: DateTime.now(),
              );
            });
          },
        ),
      ),
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final Function(String title, String content) onSave;

  const NoteEditorPage({
    super.key,
    this.initialTitle,
    this.initialContent,
    required this.onSave,
  });

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6E3EFF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.onSave(_titleController.text, _contentController.text);
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              // Implémenter la suppression
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Titre',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Écrivez votre note ici...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}