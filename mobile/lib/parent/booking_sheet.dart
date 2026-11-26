import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/teacher_listing.dart';
import '../models/teacher_profile.dart';

class BookingSheet extends StatefulWidget {
  const BookingSheet({required this.listing, required this.parentId});
  final TeacherListing listing;
  final String parentId;

  @override
  State<BookingSheet> createState() => BookingSheetState();
}

class BookingSheetState extends State<BookingSheet> {
  final _form = GlobalKey<FormState>();
  final _grade = TextEditingController();
  final _schedule = TextEditingController();
  final _notes = TextEditingController();
  String? _subject;
  String? _hood;
  late TeachingMode _mode = _modes.first;
  bool _busy = false;

  TeacherProfile get _t => widget.listing.teacher;
  List<TeachingMode> get _modes => [
        if (_t.atSchool) TeachingMode.atSchool,
        if (_t.atStudentHome) TeachingMode.atStudentHome,
        if (_t.atTeacherHome) TeachingMode.atTeacherHome,
        if (_t.teachesOnline) TeachingMode.online,
      ];

  @override
  void dispose() {
    _grade.dispose();
    _schedule.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await supabase.from('bookings').insert({
        'parent_id': widget.parentId,
        'teacher_id': _t.id,
        'student_grade': _grade.text.trim(),
        'subject': _subject,
        'teaching_mode': _mode.db,
        'neighborhood': _hood,
        'proposed_schedule': _schedule.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Request sent to ${widget.listing.name}. You will be contacted once they accept.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Request ${widget.listing.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _grade,
              decoration: const InputDecoration(labelText: "Student's grade", hintText: 'e.g. Grade 8 or O Levels'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the grade' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Subject'),
              items: [for (final s in _t.subjects) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => _subject = v,
              validator: (v) => v == null ? 'Choose a subject' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TeachingMode>(
              value: _mode,
              decoration: const InputDecoration(labelText: 'Where'),
              items: [for (final m in _modes) DropdownMenuItem(value: m, child: Text(m.label))],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Your neighbourhood'),
              items: [for (final n in _t.neighborhoods) DropdownMenuItem(value: n, child: Text(n))],
              onChanged: (v) => _hood = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _schedule,
              decoration: const InputDecoration(labelText: 'Preferred days and time', hintText: 'e.g. Mon and Wed, 5 pm'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Suggest a schedule' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Text('Send request'),
            ),
          ]),
        ),
      ),
    );
  }
}
