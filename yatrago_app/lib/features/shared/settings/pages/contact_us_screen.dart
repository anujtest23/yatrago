import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../support/data/support_api.dart';
import '../widgets/settings_ui.dart';

/// Client-side attachment limits (server re-validates). Keep in sync with the
/// backend publicImageMulterConfig (jpg/png/webp, 5 MB).
const int kMaxAttachments = 5;
const int kMaxAttachmentBytes = 5 * 1024 * 1024;
const _allowedExt = {'jpg', 'jpeg', 'png', 'webp'};

/// Uploads a list of picked image files to /support/attachments and returns
/// the server paths, in order. Throws ApiException on the first failure.
Future<List<String>> uploadAttachments(List<File> files) async {
  final urls = <String>[];
  for (final f in files) {
    urls.add(await SupportApi.uploadAttachment(f.path));
  }
  return urls;
}

/// Contact Us — submit a general support ticket (category / subject /
/// description) to the backend.
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const _categories = [
    'general',
    'account',
    'payment',
    'booking',
    'technical',
    'feedback',
  ];

  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final List<File> _attachments = [];
  String _category = 'general';
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final urls = await uploadAttachments(_attachments);
      await SupportApi.createTicket(
        category: _category,
        subject: _subject.text.trim(),
        description: _description.text.trim(),
        attachments: urls,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your message has been submitted.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SupportFormScaffold(
      title: 'Contact Us',
      subtitle: 'We usually reply within a day',
      formKey: _formKey,
      submitting: _submitting,
      onSubmit: _submit,
      fields: [
        CategoryDropdown(
          label: 'Category',
          value: _category,
          options: _categories,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 14),
        SupportTextField(
          controller: _subject,
          label: 'Subject',
          minLines: 1,
          maxLines: 1,
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Enter a short subject'
              : null,
        ),
        const SizedBox(height: 14),
        SupportTextField(
          controller: _description,
          label: 'How can we help?',
          minLines: 4,
          maxLines: 8,
          validator: (v) => (v == null || v.trim().length < 10)
              ? 'Please add a little more detail'
              : null,
        ),
        const SizedBox(height: 16),
        AttachmentsField(files: _attachments, onChanged: () => setState(() {})),
      ],
    );
  }
}

// ── Shared support-form building blocks (used by Contact Us + Report Issue) ──

class SupportFormScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final bool submitting;
  final VoidCallback onSubmit;

  const SupportFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: SettingsPageHeader(title: title, subtitle: subtitle),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Submit',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const CategoryDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: options
              .map((o) => DropdownMenuItem(
                    value: o,
                    child: Text(o[0].toUpperCase() + o.substring(1)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class SupportTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  const SupportTextField({
    super.key,
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

/// Optional screenshot attachments (max 5, jpg/png/webp, 5 MB each). Holds the
/// picked files; the parent uploads them on submit via [uploadAttachments].
class AttachmentsField extends StatefulWidget {
  final List<File> files;
  final VoidCallback onChanged;
  const AttachmentsField({
    super.key,
    required this.files,
    required this.onChanged,
  });

  @override
  State<AttachmentsField> createState() => _AttachmentsFieldState();
}

class _AttachmentsFieldState extends State<AttachmentsField> {
  Future<void> _pick() async {
    if (widget.files.length >= kMaxAttachments) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final ext = picked.path.split('.').last.toLowerCase();
    if (!_allowedExt.contains(ext)) {
      _err('Only JPG, PNG or WebP images are allowed');
      return;
    }
    final file = File(picked.path);
    if (await file.length() > kMaxAttachmentBytes) {
      _err('Each image must be under 5 MB');
      return;
    }
    setState(() => widget.files.add(file));
    widget.onChanged();
  }

  void _err(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments (optional)',
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < widget.files.length; i++)
              _thumb(widget.files[i], i),
            if (widget.files.length < kMaxAttachments) _addTile(),
          ],
        ),
      ],
    );
  }

  Widget _thumb(File f, int i) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(f, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: IconButton(
            icon: const Icon(Icons.cancel, size: 20, color: AppColors.error),
            onPressed: () {
              setState(() => widget.files.removeAt(i));
              widget.onChanged();
            },
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          color: const Color(0xFFF8FAFC),
        ),
        child: const Icon(Icons.add_a_photo_outlined,
            color: Color(0xFF94A3B8)),
      ),
    );
  }
}
