import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../core/expertise_picker.dart';
import '../core/location_field.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import '../models/teacher_profile.dart';

class _Degree {
  _Degree({String title = '', String institution = ''})
      : title = TextEditingController(text: title),
        institution = TextEditingController(text: institution);
  final TextEditingController title;
  final TextEditingController institution;
  void dispose() {
    title.dispose();
    institution.dispose();
  }
}

String _contentType(String ext) => switch (ext.toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };

/// Four-step onboarding. Used for first-time setup (from AuthGate) and for editing from the dashboard.
class TutorOnboardingScreen extends StatefulWidget {
  const TutorOnboardingScreen({super.key, required this.profile, this.existing, required this.onCompleted});

  final AppProfile profile;
  final TeacherProfile? existing;

  /// Called after a successful save. AuthGate uses it to reload and show the dashboard;
  /// the dashboard uses it to close the editor.
  final VoidCallback onCompleted;

  @override
  State<TutorOnboardingScreen> createState() => _TutorOnboardingScreenState();
}

class _TutorOnboardingScreenState extends State<TutorOnboardingScreen> {
  static const _titles = ['Profile & Bio', 'Qualifications', 'Modes & Rates', 'Verify & Submit'];

  final _page = PageController();
  final _forms = List.generate(3, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _saving = false;
  String? _stepError;

  // step 1
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _address = TextEditingController(text: widget.profile.address ?? '');
  late final _loc = LocationInput(label: widget.profile.locationLabel ?? '', lat: widget.profile.lat, lng: widget.profile.lng);
  late final _years = TextEditingController(text: (widget.existing?.yearsExperience ?? '').toString());
  late final _bio = TextEditingController(text: widget.existing?.bio ?? '');
  Uint8List? _avatarBytes;
  String? _avatarExt;

  // step 2
  final List<_Degree> _degrees = [];
  late final Set<String> _curricula = {...?widget.existing?.curricula};
  late final Set<String> _subjects = {...?widget.existing?.subjects};
  late final Set<String> _expertise = {...?widget.existing?.expertiseCategories};

  // step 3
  late bool _online = widget.existing?.teachesOnline ?? false;
  late bool _availNow = widget.existing?.isImmediatelyAvailable ?? false;
  late bool _atSchool = widget.existing?.atSchool ?? false;
  late bool _atStudent = widget.existing?.atStudentHome ?? false;
  late bool _atTeacher = widget.existing?.atTeacherHome ?? false;
  late final _salary = TextEditingController(text: _fmt(widget.existing?.monthlySalary));
  late RateType _rateType = widget.existing?.rateType ?? RateType.perMonth;
  late final _rateAmount = TextEditingController(text: _fmt(widget.existing?.rateAmount));
  late final _currentSalary = TextEditingController(text: _fmt(widget.existing?.currentSalary));
  late final Set<String> _hoods = {...?widget.existing?.neighborhoods};

  // step 4
  PlatformFile? _cnicFile;
  PlatformFile? _degreeFile;

  static String _fmt(double? v) => v == null ? '' : v.round().toString();

  @override
  void initState() {
    super.initState();
    for (final q in widget.existing?.qualifications ?? const <String>[]) {
      final i = q.indexOf(' - ');
      _degrees.add(i < 0 ? _Degree(title: q) : _Degree(title: q.substring(0, i), institution: q.substring(i + 3)));
    }
    if (_degrees.isEmpty) _degrees.add(_Degree());
  }

  @override
  void dispose() {
    for (final c in [_page, _name, _phone, _address, _years, _bio, _salary, _rateAmount, _currentSalary]) {
      c.dispose();
    }
    _loc.dispose();
    for (final d in _degrees) {
      d.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------- navigation and validation

  bool _validate(int step) {
    String? error;
    if (step < 3 && !(_forms[step].currentState?.validate() ?? true)) {
      error = 'Please fix the highlighted fields.';
    } else if (step == 1) {
      if (_curricula.isEmpty) {
        error = 'Choose at least one curriculum.';
      } else if (_subjects.isEmpty) {
        error = 'Choose at least one subject.';
      } else if (_expertise.isEmpty) {
        error = 'Choose at least one area of expertise.';
      }
    } else if (step == 2) {
      if (!_atSchool && !_atStudent && !_atTeacher && !_online) {
        error = 'Choose at least one teaching mode.';
      } else if (_hoods.isEmpty) {
        error = 'Choose at least one Lahore neighbourhood.';
      }
    }
    setState(() => _stepError = error);
    return error == null;
  }

  Future<void> _go(int step) async {
    setState(() => _step = step);
    await _page.animateToPage(step, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  Future<void> _next() async {
    if (!_validate(_step)) return;
    FocusScope.of(context).unfocus();
    await _go(_step + 1);
  }

  Future<void> _back() async {
    if (_step == 0) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    setState(() => _stepError = null);
    await _go(_step - 1);
  }

  // ---------------------------------------------------------------- pickers

  Future<void> _pickAvatar() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) showSnack(context, 'Photo is over 2 MB. Choose a smaller one.', error: true);
        return;
      }
      setState(() {
        _avatarBytes = bytes;
        _avatarExt = x.name.contains('.') ? x.name.split('.').last : 'jpg';
      });
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<PlatformFile?> _pickDoc() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final f = r?.files.firstOrNull;
    if (f == null) return null;
    if (f.bytes == null || f.size > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Choose a file under 5 MB.', error: true);
      return null;
    }
    return f;
  }

  // ---------------------------------------------------------------- submit

  bool get _needsRate => _online || _atStudent || _atTeacher; // online and home tuition need a per-day or per-month fee

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim());

  Future<String> _upload(String bucket, String path, Uint8List bytes, String ext) async {
    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: _contentType(ext)),
        );
    return path;
  }

  Future<void> _submit() async {
    if (!_validate(2)) {
      await _go(2);
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = supabase.auth.currentUser!.id;

      String? avatarUrl;
      if (_avatarBytes != null) {
        await _upload('avatars', '$uid/avatar', _avatarBytes!, _avatarExt ?? 'jpg');
        final url = supabase.storage.from('avatars').getPublicUrl('$uid/avatar');
        avatarUrl = '$url?v=${DateTime.now().millisecondsSinceEpoch}'; // busts the image cache after a change
      }
      String? cnicPath;
      if (_cnicFile != null) {
        cnicPath = await _upload('teacher_documents', '$uid/cnic.${_cnicFile!.extension ?? 'jpg'}', _cnicFile!.bytes!, _cnicFile!.extension ?? 'jpg');
      }
      String? degreePath;
      if (_degreeFile != null) {
        degreePath = await _upload('teacher_documents', '$uid/degree.${_degreeFile!.extension ?? 'jpg'}', _degreeFile!.bytes!, _degreeFile!.extension ?? 'jpg');
      }

      await supabase.from('profiles').update({
        'full_name': _name.text.trim(),
        'phone_number': _phone.text.trim(),
        'address': _address.text.trim(),
        'current_location_label': _loc.text,
        'current_lat': _loc.lat,
        'current_lng': _loc.lng,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', uid);

      // Verification fields are not sent: the database keeps them as 'pending' for teachers.
      await supabase.from('teacher_profiles').upsert({
        'id': uid,
        'bio_description': _bio.text.trim(),
        'years_experience': int.parse(_years.text.trim()),
        'qualifications': _qualificationStrings,
        'subjects': _subjects.toList(),
        'curricula': _curricula.toList(),
        'neighborhoods': _hoods.toList(),
        'available_at_school': _atSchool,
        'estimated_monthly_salary': _atSchool ? _num(_salary) : null,
        'available_at_student_home': _atStudent,
        'current_salary': _num(_currentSalary),
        'available_at_teacher_home': _atTeacher,
        'teaching_modes': [if (_online) TeachMode.online.db, if (_atTeacher) TeachMode.homeAcademy.db, if (_atStudent) TeachMode.privateHome.db],
        'is_immediately_available': _availNow,
        'expertise_categories': _expertise.toList(),
        'rate_type': _needsRate ? _rateType.db : null,
        'rate_amount': _needsRate ? _num(_rateAmount) : null,
        if (cnicPath != null) 'cnic_doc_url': cnicPath,
        if (degreePath != null) 'degree_doc_url': degreePath,
      });

      if (!mounted) return;
      showSnack(context, widget.existing == null ? 'Profile submitted. We will verify it soon.' : 'Profile updated.');
      widget.onCompleted();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> get _qualificationStrings => [
        for (final d in _degrees)
          if (d.title.text.trim().isNotEmpty)
            d.institution.text.trim().isEmpty ? d.title.text.trim() : '${d.title.text.trim()} - ${d.institution.text.trim()}',
      ];

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'Edit profile & rates' : 'Set up your profile'),
          leading: (_step > 0 || Navigator.of(context).canPop())
              ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _back)
              : null,
          actions: [
            if (!isEdit)
              IconButton(tooltip: 'Log out', onPressed: () => confirmSignOut(context), icon: const Icon(Icons.logout_rounded)),
          ],
        ),
        body: Column(children: [
          _ProgressHeader(step: _step, titles: _titles),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [_step1(), _step2(), _step3(), _step4()],
            ),
          ),
          if (_stepError != null)
            Container(
              width: double.infinity,
              color: AppColors.limeLight,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('⚠ $_stepError', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(children: [
                if (_step > 0)
                  Expanded(flex: 2, child: OutlinedButton(onPressed: _saving ? null : _back, child: const Text('Back'))),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: FilledButton(
                    onPressed: _saving ? null : (_step < 3 ? _next : _submit),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.ink))
                        : Text(_step < 3 ? 'Next' : 'Submit Profile'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // Step 1 ------------------------------------------------------------------
  Widget _step1() {
    return _StepScroll(
      form: _forms[0],
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickAvatar,
            child: Stack(children: [
              Avatar(name: _name.text.isEmpty ? 'T' : _name.text, url: widget.profile.avatarUrl, bytes: _avatarBytes, radius: 52),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, size: 20, color: AppColors.ink),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Center(child: Text('Add a friendly photo', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700))),
        const SizedBox(height: 20),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          onChanged: (_) => setState(() {}),
          validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone / WhatsApp number', hintText: '03XX XXXXXXX', helperText: 'Shared with a parent only after you accept their request'),
          validator: (v) => (v == null || !isValidPkMobile(v)) ? 'Enter a Pakistani mobile number like 0300 1234567' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _address,
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.streetAddress,
          minLines: 2,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Current Address', hintText: 'House, street, area, city', alignLabelWithHint: true, helperText: 'Never shown to parents before you accept a request'),
          validator: (v) => (v == null || v.trim().length < 8) ? 'Enter your full address' : null,
        ),
        const SizedBox(height: 14),
        LocationField(input: _loc, label: 'Current location'),
        const SizedBox(height: 14),
        TextFormField(
          controller: _years,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Years of teaching experience'),
          validator: (v) {
            final n = int.tryParse((v ?? '').trim());
            return (n == null || n < 0 || n > 60) ? 'Enter a number from 0 to 60' : null;
          },
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _bio,
          minLines: 5,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'About me & teaching style',
            alignLabelWithHint: true,
            hintText: 'How you teach, what students achieve with you, and what makes your classes different.',
          ),
        ),
      ],
    );
  }

  // Step 2 ------------------------------------------------------------------
  Widget _step2() {
    return _StepScroll(
      form: _forms[1],
      children: [
        Text('Degrees & certifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final (i, d) in _degrees.indexed)
          Card(
            color: Colors.white,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.line)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: d.title,
                      decoration: const InputDecoration(labelText: 'Degree or certificate', hintText: 'e.g. MPhil HRM'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the degree' : null,
                    ),
                  ),
                  if (_degrees.length > 1)
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.ink),
                      onPressed: () => setState(() => _degrees.removeAt(i).dispose()),
                    ),
                ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: d.institution,
                  decoration: const InputDecoration(labelText: 'Institution', hintText: 'e.g. Kinnaird College'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the institution' : null,
                ),
              ]),
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _degrees.add(_Degree())),
          icon: const Icon(Icons.add_circle_rounded),
          label: const Text('Add another degree'),
        ),
        const SizedBox(height: 16),
        Text('Curricula', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ChipSelect(options: kCurricula, selected: _curricula, onChanged: () => setState(() => _stepError = null)),
        const SizedBox(height: 20),
        Text('Subjects', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ChipSelect(options: kSubjects, selected: _subjects, onChanged: () => setState(() => _stepError = null)),
        const SizedBox(height: 20),
        ExpertisePicker(selected: _expertise, onChanged: () => setState(() => _stepError = null)),
      ],
    );
  }

  // Step 3 ------------------------------------------------------------------
  Widget _step3() {
    String? rateValidator(String? v) {
      final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
      return (n == null || n <= 0) ? 'Enter an amount in PKR' : null;
    }

    return _StepScroll(
      form: _forms[2],
      children: [
        Text('Where do you teach?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Turn on at least one.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.apartment_rounded,
          title: 'At School',
          subtitle: 'School hiring: full-time or part-time posts',
          enabled: _atSchool,
          onChanged: (v) => setState(() { _atSchool = v; _stepError = null; }),
          controller: _salary,
          label: 'Estimated monthly salary (PKR)',
          validator: rateValidator,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Teaching mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Pick one or more.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final m in TeachMode.values)
                FilterChip(
                  label: Text(m.label),
                  selected: switch (m) { TeachMode.online => _online, TeachMode.homeAcademy => _atTeacher, TeachMode.privateHome => _atStudent },
                  selectedColor: AppColors.limeLight,
                  checkmarkColor: AppColors.ink,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  onSelected: (v) => setState(() {
                    switch (m) {
                      case TeachMode.online:
                        _online = v;
                      case TeachMode.homeAcademy:
                        _atTeacher = v;
                      case TeachMode.privateHome:
                        _atStudent = v;
                    }
                    _stepError = null;
                  }),
                ),
            ]),
            const SizedBox(height: 4),
            const Text("Private Home Tuition means you teach at the student's home. Home Academy / Tuition Center means students come to you.",
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ]),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Immediately available?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const Text('Parents can filter for teachers who can start right away.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: true, label: Text('Yes')), ButtonSegment(value: false, label: Text('No'))],
              selected: {_availNow},
              onSelectionChanged: (s) => setState(() => _availNow = s.first),
            ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: !_needsRate
              ? const SizedBox(width: double.infinity)
              : Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 2)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Your tuition fee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    SegmentedButton<RateType>(
                      showSelectedIcon: false,
                      segments: [for (final r in RateType.values) ButtonSegment(value: r, label: Text(r.label))],
                      selected: {_rateType},
                      onSelectionChanged: (s) => setState(() => _rateType = s.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rateAmount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Fee ${_rateType.label.toLowerCase()} (PKR)', prefixText: 'PKR '),
                      validator: rateValidator,
                    ),
                  ]),
                ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _currentSalary,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Current Salary (PKR per month)',
            prefixText: 'PKR ',
            helperText: 'Current or most recent salary. Leave empty if you have not worked as a teacher yet.',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = double.tryParse(v.replaceAll(',', '').trim());
            return (n == null || n < 0) ? 'Enter a valid amount in PKR' : null;
          },
        ),
        const SizedBox(height: 16),
        Text('Lahore neighbourhoods you cover', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _ChipSelect(options: kNeighborhoods, selected: _hoods, onChanged: () => setState(() => _stepError = null)),
      ],
    );
  }

  // Step 4 ------------------------------------------------------------------
  Widget _step4() {
    final isEdit = widget.existing != null;
    return _StepScroll(
      children: [
        Text('Verification', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Optional, but verified teachers get the green badge and appear to parents. Files are private to you and our verification team.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        _UploadTile(
          title: 'CNIC (front)',
          fileName: _cnicFile?.name ?? (widget.existing?.cnicPath != null ? 'Already uploaded' : null),
          onPick: () async {
            final f = await _pickDoc();
            if (f != null) setState(() => _cnicFile = f);
          },
        ),
        const SizedBox(height: 10),
        _UploadTile(
          title: 'Highest degree certificate',
          fileName: _degreeFile?.name ?? (widget.existing?.degreePath != null ? 'Already uploaded' : null),
          onPick: () async {
            final f = await _pickDoc();
            if (f != null) setState(() => _degreeFile = f);
          },
        ),
        const SizedBox(height: 20),
        Text('How parents will see you', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _PreviewCard(
          name: _name.text.trim(),
          avatarUrl: widget.profile.avatarUrl,
          avatarBytes: _avatarBytes,
          qualification: _qualificationStrings.firstOrNull,
          years: int.tryParse(_years.text.trim()) ?? 0,
          subjects: _subjects.toList(),
          curricula: _curricula.toList(),
          hoods: _hoods.toList(),
          modes: [
            if (_atSchool) 'At School · ~PKR ${_salary.text}/mo',
            if (_online) 'Online',
            if (_atStudent) 'Private Home Tuition',
            if (_atTeacher) 'Home Academy / Tuition Center',
            if (_availNow) 'Available Now',
            if (_needsRate) 'Tuition fee · PKR ${_rateAmount.text} ${_rateType.label.toLowerCase()}',
          ],
        ),
        if (!isEdit) ...[
          const SizedBox(height: 12),
          const Text('After you submit, your status is Pending Verification until our team reviews your documents.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ small widgets

class _StepScroll extends StatelessWidget {
  const _StepScroll({this.form, required this.children});
  final GlobalKey<FormState>? form;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: form == null ? body : Form(key: form, child: body),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.titles});
  final int step;
  final List<String> titles;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (step + 1) / titles.length),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: AppColors.ink, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 12,
                color: AppColors.lime,
                backgroundColor: AppColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text('Step ${step + 1} of ${titles.length}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Text(titles[step], style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }
}

class _ChipSelect extends StatelessWidget {
  const _ChipSelect({required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        FilterChip(
          label: Text(o),
          selected: selected.contains(o),
          labelStyle: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink),
          onSelected: (v) {
            v ? selected.add(o) : selected.remove(o);
            onChanged();
          },
        ),
    ]);
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
    this.controller,
    this.label,
    this.validator,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final TextEditingController? controller; // only modes with their own amount (At School salary) have one
  final String? label;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: enabled ? AppColors.limeLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: enabled ? AppColors.ink : AppColors.line, width: 2),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: enabled ? AppColors.lime : AppColors.limeLight, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: enabled && controller != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: label, prefixText: 'PKR '),
                    validator: validator,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.title, required this.fileName, required this.onPick});
  final String title;
  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final done = fileName != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? AppColors.ink : AppColors.line, width: 2),
        ),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.upload_file_rounded, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(fileName ?? 'JPG, PNG or PDF, up to 5 MB', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          Text(done ? 'Change' : 'Upload', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.name,
    required this.avatarUrl,
    required this.avatarBytes,
    required this.qualification,
    required this.years,
    required this.subjects,
    required this.curricula,
    required this.hoods,
    required this.modes,
  });

  final String name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final String? qualification;
  final int years;
  final List<String> subjects;
  final List<String> curricula;
  final List<String> hoods;
  final List<String> modes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: name.isEmpty ? 'T' : name, url: avatarUrl, bytes: avatarBytes, radius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Your name' : name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(qualification ?? 'Your qualification', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$years yrs experience', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in subjects) Pill(s)]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in curricula) Pill(c),
        ]),
        const SizedBox(height: 10),
        for (final m in modes)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(m, style: const TextStyle(fontWeight: FontWeight.w800))),
        if (hoods.isNotEmpty) Text('Covers ${hoods.join(', ')}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
    );
  }
}
