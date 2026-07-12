import 'dart:io';
import 'package:flutter/material.dart';
import '../../support/data/support_api.dart';
import 'contact_us_screen.dart'
    show
        SupportFormScaffold,
        CategoryDropdown,
        SupportTextField,
        AttachmentsField,
        uploadAttachments;

/// Report an Issue — ride-specific problem report. Optionally tied to a
/// booking/ride (passed via [bookingId]/[rideId] when launched from a ride).
class ReportIssueScreen extends StatefulWidget {
  final String? bookingId;
  final String? rideId;
  const ReportIssueScreen({super.key, this.bookingId, this.rideId});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  static const _categories = [
    'driver',
    'passenger',
    'payment',
    'safety',
    'technical',
    'other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final List<File> _attachments = [];
  String _category = 'driver';
  bool _submitting = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final urls = await uploadAttachments(_attachments);
      await SupportApi.reportIssue(
        category: _category,
        description: _description.text.trim(),
        bookingId: widget.bookingId,
        rideId: widget.rideId,
        attachments: urls,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your issue has been reported.')),
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
      title: 'Report an Issue',
      subtitle: 'Tell us what went wrong',
      formKey: _formKey,
      submitting: _submitting,
      onSubmit: _submit,
      fields: [
        CategoryDropdown(
          label: 'Type of issue',
          value: _category,
          options: _categories,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 14),
        SupportTextField(
          controller: _description,
          label: 'Describe the issue',
          minLines: 5,
          maxLines: 10,
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
