import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class Note {
  final String text;
  final String userName;
  final DateTime createdAt;

  Note({required this.text, required this.userName, required this.createdAt});
}

typedef OnNoteAdded = Future<Note?> Function(BuildContext context);

class NotesSection extends StatelessWidget {
  final List<Note> notes;
  final OnNoteAdded onAddNote;

  const NotesSection({Key? key, required this.notes, required this.onAddNote})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList.radio(
      children: [
        // 1) The “Add note” panel
        ExpansionPanelRadio(
          value: 'add_note',
          headerBuilder: (_, __) => ListTile(
            leading: Icon(Icons.note_add),
            title: Text('Dodaj nową notatkę'),
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                final newNote = await onAddNote(context);
                if (newNote != null) {
                  // parent should insert into its state / Firestore
                }
              },
              child: Text('Wprowadź treść...'),
            ),
          ),
        ),

        // 2) One panel per existing note
        ...notes.map((note) {
          final header =
              '${DateFormat('dd.MM.yyyy • HH:mm').format(note.createdAt)} — ${note.userName}';
          return ExpansionPanelRadio(
            value: header,
            headerBuilder: (_, __) =>
                ListTile(leading: Icon(Icons.note), title: Text(header)),
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(note.text),
            ),
          );
        }).toList(),
      ],
    );
  }
}
