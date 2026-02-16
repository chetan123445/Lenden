import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/api_client.dart';

class ManageOffersPage extends StatefulWidget {
  const ManageOffersPage({super.key});

  @override
  State<ManageOffersPage> createState() => _ManageOffersPageState();
}

class _ManageOffersPageState extends State<ManageOffersPage> {
  List<dynamic> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  void _showStylishMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.white, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: isError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.black87))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _fetchOffers() async {
    setState(() => _loading = true);
    final res = await ApiClient.get('/api/admin/offers?includeInactive=true');
    if (res.statusCode == 200) {
      setState(() {
        _offers = jsonDecode(res.body) as List<dynamic>;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
    _showStylishMessage('Failed to fetch offers', isError: true);
  }

  Future<void> _deleteOffer(String offerId) async {
    final res = await ApiClient.delete('/api/admin/offers/$offerId');
    if (res.statusCode == 200) {
      _showStylishMessage('Offer deleted successfully');
      await _fetchOffers();
      return;
    }
    _showStylishMessage('Failed to delete offer', isError: true);
  }

  Future<void> _showOfferDialog({Map<String, dynamic>? offer}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _OfferDialog(offer: offer),
    );
    if (saved == true) {
      await _fetchOffers();
    }
  }

  Future<void> _confirmDelete(String offerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Offer?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteOffer(offerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Manage Offers',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _offers.isEmpty
                          ? const Center(child: Text('No offers yet'))
                          : RefreshIndicator(
                              onRefresh: _fetchOffers,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: _offers.length,
                                itemBuilder: (context, index) {
                                  final offer = _offers[index] as Map<String, dynamic>;
                                  final createdBy = offer['createdBy'] is Map
                                      ? (offer['createdBy']['name'] ??
                                              offer['createdBy']['username'] ??
                                              'N/A')
                                          .toString()
                                      : 'N/A';
                                  final startsAt = DateTime.tryParse('${offer['startsAt']}');
                                  final endsAt = DateTime.tryParse('${offer['endsAt']}');
                                  final createdAt = DateTime.tryParse('${offer['createdAt']}');
                                  final isActive = offer['isActive'] == true;
                                  final recipientType =
                                      (offer['recipientType'] ?? 'all-users').toString();
                                  final recipients = (offer['recipients'] as List?) ?? const [];
                                  final audienceText = recipientType == 'specific-users'
                                      ? 'Specific users (${recipients.length})'
                                      : 'All users';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [Colors.orange, Colors.white, Colors.green],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: index.isEven
                                            ? const Color(0xFFFFF4E6)
                                            : const Color(0xFFE8F5E9),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  offer['name']?.toString() ?? 'Offer',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                              ),
                                              Chip(
                                                label: Text(isActive ? 'Active' : 'Inactive'),
                                                backgroundColor: isActive
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                              ),
                                            ],
                                          ),
                                          if ((offer['description'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                            Text(offer['description'].toString()),
                                          const SizedBox(height: 8),
                                          Text('Coins: +${offer['coins']}'),
                                          Text('Audience: $audienceText'),
                                          Text(
                                            'Timeline: ${startsAt?.toLocal().toString().substring(0, 16) ?? '-'} -> ${endsAt?.toLocal().toString().substring(0, 16) ?? '-'}',
                                          ),
                                          Text('Created by: $createdBy'),
                                          Text(
                                            'Created at: ${createdAt?.toLocal().toString().substring(0, 16) ?? '-'}',
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => _showOfferDialog(offer: offer),
                                                child: const Text('Edit'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _confirmDelete(offer['_id'].toString()),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(color: Colors.red),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showOfferDialog(),
          backgroundColor: const Color(0xFF00B4D8),
          label: const Text('Add Offer'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _OfferDialog extends StatefulWidget {
  final Map<String, dynamic>? offer;
  const _OfferDialog({this.offer});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coinsController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _isActive = true;
  bool _saving = false;
  String _recipientType = 'all-users';
  bool _searchingUsers = false;
  List<Map<String, dynamic>> _searchedUsers = [];
  final Map<String, Map<String, dynamic>> _selectedUsers = {};

  void _showStylishMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.white, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: isError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    if (offer != null) {
      _nameController.text = offer['name']?.toString() ?? '';
      _descriptionController.text = offer['description']?.toString() ?? '';
      _coinsController.text = '${offer['coins'] ?? ''}';
      _startsAt = DateTime.tryParse('${offer['startsAt']}');
      _endsAt = DateTime.tryParse('${offer['endsAt']}');
      _isActive = offer['isActive'] == true;
      _recipientType = (offer['recipientType'] ?? 'all-users').toString();
      final recipients = (offer['recipients'] as List?) ?? const [];
      for (final r in recipients) {
        if (r is Map && r['_id'] != null) {
          _selectedUsers[r['_id'].toString()] = Map<String, dynamic>.from(r);
        }
      }
    } else {
      final now = DateTime.now();
      _startsAt = now;
      _endsAt = now.add(const Duration(days: 7));
      _fetchUsers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _coinsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({String search = ''}) async {
    setState(() => _searchingUsers = true);
    final path = '/api/admin/offers/users?search=${Uri.encodeQueryComponent(search)}&limit=30';
    final res = await ApiClient.get(path);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      setState(() {
        _searchedUsers = List<Map<String, dynamic>>.from(body['users'] ?? []);
        _searchingUsers = false;
      });
    } else {
      setState(() => _searchingUsers = false);
      _showStylishMessage('Failed to fetch users', isError: true);
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final base = isStart ? _startsAt ?? DateTime.now() : _endsAt ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startsAt = combined;
      } else {
        _endsAt = combined;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null || _endsAt == null) {
      _showStylishMessage('Start and end timeline are required', isError: true);
      return;
    }
    if (!_endsAt!.isAfter(_startsAt!)) {
      _showStylishMessage('End timeline must be later than start timeline', isError: true);
      return;
    }
    if (_recipientType == 'specific-users' && _selectedUsers.isEmpty) {
      _showStylishMessage('Select at least one user for specific-users offer', isError: true);
      return;
    }

    setState(() => _saving = true);
    final body = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'coins': int.parse(_coinsController.text.trim()),
      'startsAt': _startsAt!.toIso8601String(),
      'endsAt': _endsAt!.toIso8601String(),
      'isActive': _isActive,
      'recipientType': _recipientType,
      if (_recipientType == 'specific-users') 'recipientUserIds': _selectedUsers.keys.toList(),
    };

    final res = widget.offer == null
        ? await ApiClient.post('/api/admin/offers', body: body)
        : await ApiClient.put('/api/admin/offers/${widget.offer!['_id']}', body: body);

    if (!mounted) return;
    setState(() => _saving = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.of(context).pop(true);
      return;
    }

    String msg = 'Failed to save offer';
    try {
      msg = (jsonDecode(res.body)['error'] ?? msg).toString();
    } catch (_) {}
    _showStylishMessage(msg, isError: true);
  }

  Widget _sectionBox({
    required String title,
    required Widget child,
    Color background = const Color(0xFFFFFFFF),
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: background,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: const Color(0xFF00B4D8)),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _boxedTimelineTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color,
        ),
        child: ListTile(
          dense: true,
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(value?.toLocal().toString().substring(0, 16) ?? '-'),
          trailing: const Icon(Icons.event, color: Color(0xFF00B4D8)),
          onTap: onTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF5FAFF),
          ),
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offer == null ? 'Create Offer' : 'Edit Offer',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _sectionBox(
                    title: 'Offer Details',
                    icon: Icons.edit_note,
                    background: const Color(0xFFFFF8EE),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Offer name',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _coinsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Coins value',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) {
                            final n = int.tryParse((v ?? '').trim());
                            if (n == null || n <= 0) return 'Enter valid coins';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  _sectionBox(
                    title: 'Timeline',
                    icon: Icons.schedule,
                    background: const Color(0xFFEFF8FF),
                    child: Column(
                      children: [
                        _boxedTimelineTile(
                          label: 'Start date and time',
                          value: _startsAt,
                          onTap: () => _pickDateTime(isStart: true),
                          color: const Color(0xFFE8F4FF),
                        ),
                        _boxedTimelineTile(
                          label: 'End date and time',
                          value: _endsAt,
                          onTap: () => _pickDateTime(isStart: false),
                          color: const Color(0xFFFFF1E8),
                        ),
                      ],
                    ),
                  ),
                  _sectionBox(
                    title: 'Status',
                    icon: Icons.toggle_on,
                    background: const Color(0xFFF0FFF4),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Offer is active'),
                      subtitle: Text(
                        _isActive
                            ? 'Visible to users during timeline'
                            : 'Hidden from users',
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),
                  _sectionBox(
                    title: 'Audience',
                    icon: Icons.groups,
                    background: const Color(0xFFF8F1FF),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'all-users',
                          groupValue: _recipientType,
                          title: const Text('All users'),
                          onChanged: (v) => setState(() => _recipientType = v!),
                        ),
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: 'specific-users',
                          groupValue: _recipientType,
                          title: const Text('Specific users'),
                          onChanged: (v) {
                            setState(() => _recipientType = v!);
                            _fetchUsers(search: _searchController.text.trim());
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_recipientType == 'specific-users') ...[
                    _sectionBox(
                      title: 'Search Users',
                      icon: Icons.search,
                      background: const Color(0xFFFFF8EE),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search by email/username/name',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onSubmitted: (v) => _fetchUsers(search: v.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B4D8),
                            ),
                            onPressed: () => _fetchUsers(search: _searchController.text.trim()),
                            child: const Text('Search', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedUsers.isNotEmpty)
                      _sectionBox(
                        title: 'Selected Users (${_selectedUsers.length})',
                        icon: Icons.check_circle,
                        background: const Color(0xFFEFFBF1),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedUsers.values.map((u) {
                            final id = u['_id'].toString();
                            final email = (u['email'] ?? '').toString();
                            return Chip(
                              backgroundColor: const Color(0xFFE3F2FD),
                              label: Text(email.isNotEmpty ? email : id),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() {
                                  _selectedUsers.remove(id);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    _sectionBox(
                      title: 'Choose Users',
                      icon: Icons.person_search,
                      background: const Color(0xFFEFF8FF),
                      child: _searchingUsers
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(
                              height: 180,
                              child: _searchedUsers.isEmpty
                                  ? const Center(child: Text('No users found'))
                                  : ListView.builder(
                                      itemCount: _searchedUsers.length,
                                      itemBuilder: (_, i) {
                                        final user = _searchedUsers[i];
                                        final id = user['_id'].toString();
                                        final selected = _selectedUsers.containsKey(id);
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? const Color(0xFFE8F5E9)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: CheckboxListTile(
                                            value: selected,
                                            title: Text(
                                              (user['name'] ?? user['username'] ?? 'User')
                                                  .toString(),
                                            ),
                                            subtitle: Text((user['email'] ?? '').toString()),
                                            onChanged: (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedUsers[id] = user;
                                                } else {
                                                  _selectedUsers.remove(id);
                                                }
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                            ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.3,
      size.width,
      size.height * 0.4,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
