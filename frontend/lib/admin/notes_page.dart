import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';

class AdminNotesPage extends StatefulWidget {
  const AdminNotesPage({Key? key}) : super(key: key);
  @override
  State<AdminNotesPage> createState() => _AdminNotesPageState();
}

class _AdminNotesPageState extends State<AdminNotesPage> {
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> filteredNotes = [];
  bool loading = true;
  String? error;
  String searchQuery = '';
  String sortBy = 'created_desc'; // Options: created_desc, created_asc, updated_desc, updated_asc, title_az, title_za

  @override
  void initState() {
    super.initState();
    fetchNotes();
  }

  void sortNotes() {
    setState(() {
      filteredNotes.sort((a, b) {
        switch (sortBy) {
          case 'created_asc':
            return (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? '');
          case 'created_desc':
            return (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? '');
          case 'updated_asc':
            return (a['updatedAt'] ?? '').compareTo(b['updatedAt'] ?? '');
          case 'updated_desc':
            return (b['updatedAt'] ?? '').compareTo(a['updatedAt'] ?? '');
          case 'title_az':
            return (a['title'] ?? '').toLowerCase().compareTo((b['title'] ?? '').toLowerCase());
          case 'title_za':
            return (b['title'] ?? '').toLowerCase().compareTo((a['title'] ?? '').toLowerCase());
          default:
            return 0;
        }
      });
    });
  }

  void filterNotes(String query) {
    setState(() {
      searchQuery = query;
      filteredNotes = notes.where((note) => (note['title'] ?? '').toLowerCase().contains(query.toLowerCase())).toList();
      sortNotes();
    });
  }

  Future<void> fetchNotes() async {
    setState(() { loading = true; error = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/notes';
    final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final fetchedNotes = List<Map<String, dynamic>>.from(json.decode(res.body)['notes']);
      setState(() {
        notes = fetchedNotes;
        filteredNotes = fetchedNotes;
        sortNotes();
        loading = false;
      });
    } else {
      setState(() { error = 'Failed to load notes'; loading = false; });
    }
  }

  Future<void> createOrEditNote({Map<String, dynamic>? note}) async {
    final titleController = TextEditingController(text: note?['title'] ?? '');
    final contentController = TextEditingController(text: note?['content'] ?? '');
    final isEdit = note != null;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(isEdit ? 'Edit Note' : 'New Note', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(hintText: 'Title'),
              maxLength: 50,
            ),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: InputDecoration(hintText: 'Enter note...'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00B4D8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return;
              Navigator.pop(context, {'title': title, 'content': content});
            },
            child: Text(isEdit ? 'Update' : 'Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result['title']!.isNotEmpty && result['content']!.isNotEmpty) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      if (isEdit) {
        final url = '${ApiConfig.baseUrl}/api/notes/${note!['_id']}';
        final res = await http.put(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({'title': result['title'], 'content': result['content']}),
        );
        if (res.statusCode == 200) fetchNotes();
      } else {
        final url = '${ApiConfig.baseUrl}/api/notes';
        final res = await http.post(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({'title': result['title'], 'content': result['content']}),
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

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
          // Top blue shape
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 120,
                color: const Color(0xFF00B4D8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/admin/dashboard');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom blue shape
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: 90,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  Center(
                    child: Text(
                      'Admin Notes',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by title...',
                            prefixIcon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                            ),
                          ),
                          onChanged: filterNotes,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: sortBy,
                        borderRadius: BorderRadius.circular(16),
                        style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
                        underline: Container(),
                        items: const [
                          DropdownMenuItem(value: 'created_desc', child: Text('Newest')),
                          DropdownMenuItem(value: 'created_asc', child: Text('Oldest')),
                          DropdownMenuItem(value: 'updated_desc', child: Text('Recently Updated')),
                          DropdownMenuItem(value: 'updated_asc', child: Text('Least Updated')),
                          DropdownMenuItem(value: 'title_az', child: Text('Title A-Z')),
                          DropdownMenuItem(value: 'title_za', child: Text('Title Z-A')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              sortBy = val;
                              sortNotes();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : error != null
                            ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                            : filteredNotes.isEmpty
                                ? Center(child: Text('Nothing to show yet, create your first note...', style: TextStyle(color: Colors.grey, fontSize: 16)))
                                : ListView.separated(
                                    itemCount: filteredNotes.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, i) {
                                      final note = filteredNotes[i];
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    note['title'] ?? '(No Title)',
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8)),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    note['content'] ?? '',
                                                    style: const TextStyle(fontSize: 16, color: Colors.black),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text('Created: ${_formatDate(note['createdAt'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                      const SizedBox(width: 12),
                                                      Icon(Icons.update, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Text('Updated: ${_formatDate(note['updatedAt'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Color(0xFF00B4D8)),
                                                  onPressed: () => createOrEditNote(note: note),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  onPressed: () => deleteNote(note['_id']),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => createOrEditNote(),
        backgroundColor: const Color(0xFF00B4D8),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Note',
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
} 