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
        if (res.statusCode == 200) {
          // Update local state instead of reloading
          final updatedNote = Map<String, dynamic>.from(note);
          updatedNote['title'] = result['title'];
          updatedNote['content'] = result['content'];
          updatedNote['updatedAt'] = DateTime.now().toIso8601String();
          
          setState(() {
            final index = notes.indexWhere((n) => n['_id'] == note['_id']);
            if (index != -1) {
              notes[index] = updatedNote;
              filterNotes(searchQuery); // Reapply filter and sort
            }
          });
        }
      } else {
        final url = '${ApiConfig.baseUrl}/api/notes';
        final res = await http.post(Uri.parse(url),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: json.encode({'title': result['title'], 'content': result['content']}),
        );
        if (res.statusCode == 201) {
          // Add new note to local state instead of reloading
          final newNote = json.decode(res.body)['note'];
          setState(() {
            notes.insert(0, newNote);
            filterNotes(searchQuery); // Reapply filter and sort
          });
        }
      }
    }
  }

  Future<void> deleteNote(String id) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/notes/$id';
    final res = await http.delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      // Remove note from local state instead of reloading
      setState(() {
        notes.removeWhere((note) => note['_id'] == id);
        filterNotes(searchQuery); // Reapply filter and sort
      });
    }
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
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: filterNotes,
                            decoration: InputDecoration(
                              hintText: 'Search by title...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                            onPressed: () => filterNotes(''),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFF00B4D8), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButton<String>(
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
                                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                                    itemBuilder: (context, i) {
                                      final note = filteredNotes[i];
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Color(0xFF00B4D8).withOpacity(0.3),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.08),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(20),
                                          scrollDirection: Axis.horizontal,
                                          child: IntrinsicWidth(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Container(
                                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: Color(0xFF00B4D8).withOpacity(0.1),
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(
                                                                color: Color(0xFF00B4D8).withOpacity(0.3),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              note['title'] ?? '(No Title)',
                                                              style: const TextStyle(
                                                                fontSize: 18, 
                                                                fontWeight: FontWeight.bold, 
                                                                color: Color(0xFF00B4D8)
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 12),
                                                          Container(
                                                            padding: EdgeInsets.all(16),
                                                            decoration: BoxDecoration(
                                                              color: Colors.grey.withOpacity(0.05),
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(
                                                                color: Colors.grey.withOpacity(0.2),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              note['content'] ?? '',
                                                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      children: [
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Color(0xFF00B4D8).withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Color(0xFF00B4D8).withOpacity(0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: IconButton(
                                                            icon: const Icon(Icons.edit, color: Color(0xFF00B4D8)),
                                                            onPressed: () => createOrEditNote(note: note),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.withOpacity(0.1),
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: Colors.red.withOpacity(0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: IconButton(
                                                            icon: const Icon(Icons.delete, color: Colors.red),
                                                            onPressed: () => deleteNote(note['_id']),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.grey.withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                                      const SizedBox(width: 4),
                                                      Text('Created: ${_formatDate(note['createdAt'])}', 
                                                           style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                      const SizedBox(width: 16),
                                                      Icon(Icons.update, size: 14, color: Colors.grey[600]),
                                                      const SizedBox(width: 4),
                                                      Text('Updated: ${_formatDate(note['updatedAt'])}', 
                                                           style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
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