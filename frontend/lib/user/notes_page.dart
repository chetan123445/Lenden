import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import 'session.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({Key? key}) : super(key: key);
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Map<String, dynamic>> notes = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchNotes();
  }

  Future<void> fetchNotes() async {
    setState(() { loading = true; error = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/notes';
    final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      setState(() {
        notes = List<Map<String, dynamic>>.from(json.decode(res.body)['notes']);
        loading = false;
      });
    } else {
      setState(() { error = 'Failed to load notes'; loading = false; });
    }
  }

  Future<void> createOrEditNote({Map<String, dynamic>? note}) async {
    final controller = TextEditingController(text: note?['content'] ?? '');
    final isEdit = note != null;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Note' : 'New Note'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(hintText: 'Enter note...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(isEdit ? 'Update' : 'Create')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      if (isEdit) {
        final url = '${ApiConfig.baseUrl}/api/notes/${note!['_id']}';
        final res = await http.put(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({'content': result}),
        );
        if (res.statusCode == 200) fetchNotes();
      } else {
        final url = '${ApiConfig.baseUrl}/api/notes';
        final res = await http.post(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({'content': result}),
        );
        if (res.statusCode == 201) fetchNotes();
      }
    }
  }

  Future<void> deleteNote(String id) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/notes/$id';
    final res = await http.delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) fetchNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes')),
      body: loading
        ? Center(child: CircularProgressIndicator())
        : error != null
          ? Center(child: Text(error!))
          : notes.isEmpty
            ? Center(child: Text('No notes yet.'))
            : ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (_, __) => Divider(),
                itemBuilder: (context, i) {
                  final note = notes[i];
                  return ListTile(
                    title: Text(note['content'] ?? ''),
                    subtitle: Text('Last updated: ' + (note['updatedAt'] != null ? note['updatedAt'].toString().substring(0, 16).replaceAll('T', ' ') : '')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: Icon(Icons.edit), onPressed: () => createOrEditNote(note: note)),
                        IconButton(icon: Icon(Icons.delete, color: Colors.red), onPressed: () => deleteNote(note['_id'])),
                      ],
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => createOrEditNote(),
        child: Icon(Icons.add),
        tooltip: 'Add Note',
      ),
    );
  }
} 