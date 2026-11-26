import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account_drawer.dart';
import '../core/constants.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import '../models/teacher_profile.dart';
import 'requests_map_section.dart';
import 'tutor_onboarding_screen.dart';

/// Teacher home: verification status, accepting-students switch, stats, and a live list of parent requests.
class TutorDashboardScreen extends StatefulWidget {
  const TutorDashboardScreen({super.key});

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  AppProfile? _profile;
  TeacherProfile? _teacher;
  List<BookingRequest> _bookings = const [];
  String _filter = 'pending';
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // New and changed requests arrive live. Realtime applies the bookings RLS policies, so a teacher only
    // receives their own rows. The list itself comes from teacher_bookings() because it joins the parent's name.
    _channel = supabase
        .channel('bookings-$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'teacher_id', value: _uid),
          callback: (_) => _loadBookings(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final c = _channel;
    if (c != null) supabase.removeChannel(c);
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final rows = await supabase.rpc('get_my_profile') as List;
      final row = await supabase.from('teacher_profiles').select().eq('id', _uid).single();
      final bookings = await _fetchBookings();
      if (!mounted) return;
      setState(() {
        _profile = AppProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));
        _teacher = TeacherProfile.fromMap(row);
        _bookings = bookings;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = errorText(e); _loading = false; });
    }
  }

  Future<List<BookingRequest>> _fetchBookings() async {
    final rows = await supabase.rpc('teacher_bookings') as List;
    return rows.map((r) => BookingRequest.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<void> _loadBookings() async {
    try {
      final b = await _fetchBookings();
      if (mounted) setState(() => _bookings = b);
    } catch (_) {/* the next pull-to-refresh will surface a persistent problem */}
  }

  Future<void> _toggleAccepting(bool value) async {
    final t = _teacher!;
    setState(() => _teacher = TeacherProfile.fromMap({..._asMap(t), 'is_accepting_students': value}));
    try {
      await supabase.from('teacher_profiles').update({'is_accepting_students': value}).eq('id', _uid);
    } catch (e) {
      if (!mounted) return;
      setState(() => _teacher = t); // put it back
      showSnack(context, errorText(e), error: true);
    }
  }

  // Rebuilds the row map so the switch can update optimistically.
  Map<String, dynamic> _asMap(TeacherProfile t) => {
        'id': t.id,
        'bio_description': t.bio,
        'qualifications': t.qualifications,
        'years_experience': t.yearsExperience,
        'subjects': t.subjects,
        'curricula': t.curricula,
        'neighborhoods': t.neighborhoods,
        'available_at_school': t.atSchool,
        'estimated_monthly_salary': t.monthlySalary,
        'available_at_student_home': t.atStudentHome,
        'current_salary': t.currentSalary,
        'available_at_teacher_home': t.atTeacherHome,
        'rate_type': t.rateType?.db,
        'rate_amount': t.rateAmount,
        'verification_status': t.verificationStatus,
        'cnic_doc_url': t.cnicPath,
        'degree_doc_url': t.degreePath,
        'is_accepting_students': t.isAccepting,
        'is_star_teacher': t.isStar,
        'rating_avg': t.ratingAvg,
        'reviews_count': t.reviewsCount,
      };

  Future<void> _setStatus(BookingRequest b, String status) async {
    try {
      await supabase.from('bookings').update({'status': status}).eq('id', b.id);
      await _loadBookings(); // after accepting, the parent's phone number is now included
      if (!mounted) return;
      showSnack(context, status == 'accepted' ? "Accepted. ${b.parentName}'s contact number is now visible." : 'Request declined.');
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _confirmDecline(BookingRequest b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline this request?'),
        content: Text('${b.parentName} will be told you are unable to take this tuition.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44), backgroundColor: AppColors.white, foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok == true) await _setStatus(b, 'declined');
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => TutorOnboardingScreen(
        profile: _profile!,
        existing: _teacher,
        onCompleted: () => Navigator.of(ctx).pop(),
      ),
    ));
    if (mounted) _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.ink)));
    if (_error != null || _teacher == null || _profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () { setState(() => _loading = true); _loadAll(); }, child: const Text('Try again')),
            ]),
          ),
        ),
      );
    }

    final t = _teacher!;
    final p = _profile!;
    int count(String s) => _bookings.where((b) => b.status == s).length;
    final shown = _bookings.where((b) => b.status == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(tooltip: 'Log out', onPressed: () => confirmSignOut(context), icon: const Icon(Icons.logout_rounded)),
          Builder(
            builder: (ctx) => IconButton(tooltip: 'Account', onPressed: () => Scaffold.of(ctx).openEndDrawer(), icon: const Icon(Icons.account_circle_rounded)),
          ),
        ],
      ),
      endDrawer: AccountDrawer(profile: p, onReturn: _loadAll),
      body: RefreshIndicator(
        color: AppColors.ink,
        onRefresh: _loadAll,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Rise(child: _Header(profile: p, teacher: t)),
          const SizedBox(height: 12),
          Rise(delayMs: 30, child: TutorMapSection(profile: p, verified: t.isVerified)),
          const SizedBox(height: 14),
          Rise(
            delayMs: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: t.isAccepting ? AppColors.lime : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepting New Students', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(t.isAccepting ? 'Parents can send you requests' : 'Hidden from the parent board for now'),
                value: t.isAccepting,
                onChanged: _toggleAccepting,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Rise(
            delayMs: 120,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _Stat(icon: Icons.mark_email_unread_rounded, label: 'Pending Requests', value: '${count('pending')}', color: AppColors.ink),
                _Stat(icon: Icons.school_rounded, label: 'Active Tuitions', value: '${count('accepted')}', color: AppColors.ink),
                _Stat(
                    icon: Icons.star_rounded,
                    label: 'Star Rating',
                    value: t.reviewsCount == 0 ? 'New' : '${t.ratingAvg.toStringAsFixed(1)} (${t.reviewsCount})',
                    color: AppColors.ink),
                _Stat(icon: Icons.tune_rounded, label: 'Active Modes', value: '${t.activeModes} of 3', color: AppColors.ink),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Edit profile & rates'),
          ),
          const SizedBox(height: 22),
          Text('Parent requests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'pending', label: Text('Pending ${count('pending')}')),
              ButtonSegment(value: 'accepted', label: Text('Accepted ${count('accepted')}')),
              ButtonSegment(value: 'declined', label: Text('Declined ${count('declined')}')),
            ],
            selected: {_filter},
            onSelectionChanged: (s) => setState(() => _filter = s.first),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: AppColors.limeLight, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const Icon(Icons.inbox_rounded, size: 40, color: AppColors.ink),
                const SizedBox(height: 8),
                Text(
                  _filter == 'pending'
                      ? (t.isVerified ? 'No new requests yet. They will appear here as they arrive.' : 'Requests will start once your profile is verified.')
                      : 'Nothing here yet.',
                  textAlign: TextAlign.center,
                ),
              ]),
            )
          else
            for (final (i, b) in shown.indexed)
              Rise(
                key: ValueKey(b.id),
                delayMs: i * 50,
                child: _RequestCard(
                  booking: b,
                  onAccept: () => _setStatus(b, 'accepted'),
                  onDecline: () => _confirmDecline(b),
                ),
              ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.teacher});
  final AppProfile profile;
  final TeacherProfile teacher;

  @override
  Widget build(BuildContext context) {
    final status = switch (teacher.verificationStatus) {
      'verified' => const Pill('Verified Educator', color: AppColors.ink, background: AppColors.lime, icon: Icons.verified_rounded),
      'rejected' => const Pill('Verification Rejected', color: AppColors.ink, background: AppColors.limeLight, icon: Icons.error_rounded),
      _ => const Pill('Pending Verification', color: AppColors.ink, background: AppColors.lime, icon: Icons.hourglass_top_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: teacher.isStar ? AppColors.ink : AppColors.line, width: teacher.isStar ? 2.5 : 1.5),
      ),
      child: Row(children: [
        Avatar(name: profile.fullName, url: profile.avatarUrl, radius: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(profile.fullName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [if (teacher.isStar) const StarBadge(), status]),
            if (teacher.verificationStatus == 'pending')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Parents see your profile once our team verifies it.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.booking, required this.onAccept, required this.onDecline});
  final BookingRequest booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showSnack(context, 'Could not open that app.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final mode = TeachingMode.fromDb(b.mode);
    final phone = b.parentPhone;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: b.parentName, radius: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(b.parentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          if (mode != null) Pill(mode.label, icon: switch (mode) {
            TeachingMode.atSchool => Icons.apartment_rounded,
            TeachingMode.atStudentHome => Icons.home_rounded,
            TeachingMode.atTeacherHome => Icons.meeting_room_rounded,
            TeachingMode.online => Icons.videocam_rounded,
          }),
        ]),
        const SizedBox(height: 10),
        _line(Icons.menu_book_rounded, [b.subject, b.grade].where((x) => x != null && x.isNotEmpty).join(' · ')),
        if ((b.neighborhood ?? '').isNotEmpty) _line(Icons.place_rounded, b.neighborhood!),
        if ((b.schedule ?? '').isNotEmpty) _line(Icons.schedule_rounded, b.schedule!),
        if ((b.notes ?? '').isNotEmpty) _line(Icons.notes_rounded, b.notes!),
        if (b.status == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: AppColors.ink, side: const BorderSide(color: AppColors.ink, width: 2)),
                onPressed: onDecline,
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)), onPressed: onAccept, child: const Text('Accept')),
            ),
          ]),
        ],
        if (b.status == 'accepted') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (phone == null || phone.isEmpty)
                const Text('This parent did not add a phone number.')
              else
                Row(children: [
                  const Icon(Icons.phone_rounded, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Expanded(child: Text(phone, style: const TextStyle(fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'Call', icon: const Icon(Icons.call_rounded, color: AppColors.ink), onPressed: () => _open(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', '')))),
                  IconButton(tooltip: 'WhatsApp', icon: const Icon(Icons.chat_rounded, color: AppColors.ink), onPressed: () => _open(context, Uri.parse('https://wa.me/${toInternational(phone)}'))),
                ]),
              if ((b.parentAddress ?? '').isNotEmpty || (b.parentLocationLabel ?? '').isNotEmpty) ...[
                const Divider(height: 18),
                if ((b.parentAddress ?? '').isNotEmpty)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.home_rounded, size: 18, color: AppColors.ink),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b.parentAddress!, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                if ((b.parentLocationLabel ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.my_location_rounded, size: 18, color: AppColors.ink),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Currently near ${b.parentLocationLabel!}', style: const TextStyle(color: AppColors.muted))),
                    ]),
                  ),
                TextButton.icon(
                  onPressed: () => _open(context, _mapsUri(b)),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Open in Maps'),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Uri _mapsUri(BookingRequest b) => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': (b.parentLat != null && b.parentLng != null) ? '${b.parentLat},${b.parentLng}' : (b.parentAddress ?? b.parentLocationLabel ?? ''),
      });

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}
