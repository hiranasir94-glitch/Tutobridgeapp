import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

/// A parent tells teachers what they are looking for. Teachers near them see it on their map and can start a chat.
/// Only a first name, the subject and an approximate position are shared; never the address or phone number.
class TuitionRequestSheet extends StatefulWidget {
  const TuitionRequestSheet({super.key, required this.hasLocation});
  final bool hasLocation;

  @override
  State<TuitionRequestSheet> createState() => _TuitionRequestSheetState();
}

class _TuitionRequestSheetState extends State<TuitionRequestSheet> {
  String? _subject;
  String? _curriculum;
  final _grade = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>> _open = const [];

  @override
  void initState() {
    super.initState();
    _loadOpen();
  }

  @override
  void dispose() {
    _grade.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadOpen() async {
    try {
      final rows = await supabase.from('tuition_requests').select('id, subject, grade, created_at').eq('status', 'open').order('created_at', ascending: false);
      if (mounted) setState(() => _open = List<Map<String, dynamic>>.from(rows as List));
    } catch (_) {/* the list is optional */}
  }

  Future<void> _submit() async {
    if (_subject == null) {
      showSnack(context, 'Choose a subject first.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await supabase.from('tuition_requests').insert({
        'parent_id': supabase.auth.currentUser!.id,
        'subject': _subject,
        'curriculum': _curriculum,
        'grade': _grade.text.trim().isEmpty ? null : _grade.text.trim(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Request posted. Teachers nearby can now see it.');
    } catch (e) {
      final msg = errorText(e);
      if (mounted) {
        showSnack(context, msg.contains('row-level security') ? 'You can have up to 3 open requests. Close one first.' : msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close(String id) async {
    try {
      await supabase.from('tuition_requests').update({'status': 'closed'}).eq('id', id);
      await _loadOpen();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Post a tuition request', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Nearby teachers see your first name, the subject and your approximate area. Your address and phone number stay private.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          if (!widget.hasLocation)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
              child: const Text('Save your current location in Account > Address so teachers can see your request on their map.', style: TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 14),
          const Text('Subject', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(spacing: 8, children: [
            for (final s in kSubjects) ChoiceChip(label: Text(s), selected: _subject == s, onSelected: (_) => setState(() => _subject = s)),
          ]),
          const SizedBox(height: 12),
          const Text('Curriculum (optional)', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(spacing: 8, children: [
            for (final c in kCurricula)
              ChoiceChip(label: Text(c), selected: _curriculum == c, onSelected: (v) => setState(() => _curriculum = v ? c : null)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _grade, maxLength: 60, decoration: const InputDecoration(labelText: 'Class / grade (optional)', hintText: 'e.g. Grade 9')),
          TextField(controller: _note, maxLength: 300, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Preferred timing, mode, anything else')),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Posting...' : 'Post request'))),
          if (_open.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Your open requests', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final r in _open)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${r['subject']}${r['grade'] != null ? ' · ${r['grade']}' : ''}'),
                trailing: TextButton(onPressed: () => _close('${r['id']}'), child: const Text('Close')),
              ),
          ],
        ]),
      ),
    );
  }
}
