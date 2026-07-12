import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../data/emergency_contacts_api.dart';
import '../widgets/settings_ui.dart';

/// Emergency Contacts — add / edit / delete / reorder (max 3). All rules
/// (duplicate prevention, cap, ownership) are enforced server-side; this
/// screen surfaces the errors.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await EmergencyContactsApi.list();
      if (!mounted) return;
      setState(() {
        _contacts = list.cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContactForm(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await EmergencyContactsApi.add(
          fullName: result['fullName']!,
          phoneNumber: result['phoneNumber']!,
          relationship: result['relationship'],
        );
      } else {
        await EmergencyContactsApi.update(existing['id'] as String, {
          'fullName': result['fullName'],
          'phoneNumber': result['phoneNumber'],
          'relationship': result['relationship'],
        });
      }
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove contact'),
        content: Text('Remove ${c['fullName']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await EmergencyContactsApi.remove(c['id'] as String);
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final prev = List<Map<String, dynamic>>.from(_contacts);
    setState(() {
      final item = _contacts.removeAt(oldIndex);
      _contacts.insert(newIndex, item);
    });
    try {
      await EmergencyContactsApi.reorder(
        _contacts.map((c) => c['id'] as String).toList(),
      );
    } catch (e) {
      setState(() => _contacts = prev);
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _contacts.length < 3;
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: SettingsPageHeader(
                title: 'Emergency Contacts',
                subtitle: 'Up to 3 people we can reach in an emergency',
              ),
            ),
            Expanded(child: _body()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: canAdd ? () => _openForm() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    canAdd ? 'Add Contact' : 'Maximum 3 contacts',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.error)),
        ),
      );
    }
    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contact_phone_outlined,
                size: 56, color: AppColors.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No emergency contacts yet',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ],
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _contacts.length,
      // ignore: deprecated_member_use
      onReorder: _reorder,
      itemBuilder: (context, i) {
        final c = _contacts[i];
        return Container(
          key: ValueKey(c['id']),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                (c['fullName'] as String? ?? '?')
                    .trim()
                    .characters
                    .first
                    .toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            title: Text(c['fullName'] ?? '',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [c['phoneNumber'], c['relationship']]
                  .where((e) => e != null && (e as String).isNotEmpty)
                  .join(' · '),
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: const Color(0xFF64748B)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppColors.primary,
                  onPressed: () => _openForm(existing: c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: AppColors.error,
                  onPressed: () => _delete(c),
                ),
                ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle_rounded,
                      color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ContactForm({this.existing});

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _rel;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?['fullName'] ?? '');
    _phone = TextEditingController(text: widget.existing?['phoneNumber'] ?? '');
    _rel = TextEditingController(text: widget.existing?['relationship'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add Contact' : 'Edit Contact',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _field(_name, 'Full name', validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            }),
            const SizedBox(height: 12),
            _field(_phone, 'Phone number',
                keyboardType: TextInputType.phone, validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^\+?\d{7,15}$').hasMatch(v.trim())) {
                return 'Enter a valid phone number';
              }
              return null;
            }),
            const SizedBox(height: 12),
            _field(_rel, 'Relationship (optional)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context, {
                    'fullName': _name.text.trim(),
                    'phoneNumber': _phone.text.trim(),
                    'relationship': _rel.text.trim(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Save',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
