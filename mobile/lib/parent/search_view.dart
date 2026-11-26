import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../core/constants.dart';
import '../core/portrait.dart';
import '../core/supabase.dart';
import '../core/stickers.dart';
import '../core/teacher_banner.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/mock_teachers.dart';
import '../models/app_profile.dart';
import '../models/teacher_listing.dart';
import '../models/teacher_profile.dart';
import 'booking_sheet.dart';
import 'featured_online.dart';
import 'map_section.dart';
import 'search_filters.dart';
import 'teacher_card.dart';

/// The Search tab: nearby verified teachers, sorted by distance when the parent has saved a location.
class SearchView extends StatefulWidget {
  const SearchView({super.key, required this.profile, this.refreshToken = 0});
  final AppProfile profile;

  /// Change this number to make the view reload (used after the parent changes their address).
  final int refreshToken;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late Future<List<TeacherListing>> _future = _load();
  late AppProfile _me = widget.profile;
  late Future<List<TeacherListing>> _featuredFuture = _loadFeatured();
  final SearchFilters _f = SearchFilters();
  final _resultsKey = GlobalKey();
  String _query = '';
  String? _connectingId;

  @override
  void didUpdateWidget(covariant SearchView old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) {
      setState(() {
        _future = _load();
        _featuredFuture = _loadFeatured();
      });
    }
  }

  /// Reloads the board after a filter changed. Filtering happens in the database (array overlap on
  /// teaching_modes and expertise_categories), so the result is accurate even with many teachers.
  void _applyFilters({bool scroll = false}) {
    setState(() => _future = _load());
    if (scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _resultsKey.currentContext;
        if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      });
    }
  }

  TeacherListing _toListing(Map<String, dynamic> m, Map<String, double> km) {
    final p = Map<String, dynamic>.from(m['profiles'] as Map);
    final t = TeacherProfile.fromMap(m);
    return TeacherListing(t, (p['full_name'] as String?) ?? '', p['avatar_url'] as String?, distanceKm: km[t.id]);
  }

  /// Verified teachers who teach online, available-now teachers first.
  Future<List<TeacherListing>> _loadFeatured() async {
    final rows = await supabase
        .from('teacher_profiles')
        .select('*, profiles!inner(full_name, avatar_url)')
        .eq('verification_status', 'verified')
        .eq('is_accepting_students', true)
        .overlaps('teaching_modes', [TeachMode.online.db])
        .order('is_immediately_available', ascending: false)
        .order('rating_avg', ascending: false)
        .limit(12);
    return (rows as List).map((r) => _toListing(Map<String, dynamic>.from(r as Map), const {})).toList();
  }

  Future<List<TeacherListing>> _load() async {
    // Fresh copy of the parent's own profile so a changed address shows up straight away.
    try {
      final rows = await supabase.rpc('get_my_profile') as List;
      if (rows.isNotEmpty && mounted) _me = AppProfile.fromMap(Map<String, dynamic>.from(rows.first as Map));
    } catch (_) {/* keep the profile we were given */}

    var query = supabase
        .from('teacher_profiles')
        .select('*, profiles!inner(full_name, avatar_url)')
        .eq('verification_status', 'verified')
        .eq('is_accepting_students', true);
    if (_f.nowOnly) query = query.eq('is_immediately_available', true);
    if (_f.cats.isNotEmpty) query = query.overlaps('expertise_categories', _f.cats.toList());
    final modeList = [for (final m in _f.modes) m.db];
    if (_f.school && modeList.isNotEmpty) {
      query = query.or('available_at_school.eq.true,teaching_modes.ov.{${modeList.join(',')}}');
    } else if (_f.school) {
      query = query.eq('available_at_school', true);
    } else if (modeList.isNotEmpty) {
      query = query.overlaps('teaching_modes', modeList);
    }
    final rows = await query.order('is_immediately_available', ascending: false).order('is_star_teacher', ascending: false).order('rating_avg', ascending: false);

    // Distances come from the database, rounded, so teachers' exact positions are never sent to the app.
    final km = <String, double>{};
    try {
      for (final r in await supabase.rpc('nearby_teacher_distances') as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final d = double.tryParse('${m['distance_km']}');
        if (d != null) km['${m['teacher_id']}'] = d;
      }
    } catch (_) {/* sort by rating instead */}

    final list = (rows as List).map((r) => _toListing(Map<String, dynamic>.from(r as Map), km)).toList();

    if (km.isNotEmpty) {
      list.sort((a, b) => (a.distanceKm ?? double.infinity).compareTo(b.distanceKm ?? double.infinity));
    }
    return list;
  }

  List<TeacherListing> _filter(List<TeacherListing> all) {
    final q = _query.trim().toLowerCase();
    return all.where((l) {
      if (q.isEmpty) return true;
      final hay = [l.name, ...l.teacher.subjects, ...l.teacher.curricula, ...l.teacher.neighborhoods, ...l.teacher.qualifications]
          .join(' ')
          .toLowerCase();
      return q.split(RegExp(r'\s+')).every(hay.contains);
    }).toList();
  }

  Future<void> _connect(TeacherListing l) async {
    if (l.isSample) {
      showSnack(context, 'This is a sample profile. Real teachers will appear here once they are verified.');
      return;
    }
    setState(() => _connectingId = l.teacher.id);
    try {
      final id = await supabase.rpc('start_conversation', params: {'p_teacher_id': l.teacher.id}) as String;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(conversationId: id, otherName: l.name, otherAvatarUrl: l.avatarUrl),
      ));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  void _book(TeacherListing l) {
    if (l.isSample) {
      showSnack(context, 'This is a sample profile. Real teachers will appear here once they are verified.');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BookingSheet(listing: l, parentId: _me.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async => setState(() => _future = _load()),
      child: FutureBuilder<List<TeacherListing>>(
        future: _future,
        builder: (context, snap) {
          final done = snap.connectionState == ConnectionState.done;
          final real = snap.data ?? const <TeacherListing>[];
          final useSample = done && !snap.hasError && real.isEmpty && !_f.any;
          final source = useSample ? mockTeachers() : real;
          final shown = _filter(source);
          final hasDistances = real.any((l) => l.distanceKm != null);
          final where = (_me.locationLabel ?? '').isNotEmpty ? _me.locationLabel! : (_me.city ?? 'Lahore');

          return ListView(padding: const EdgeInsets.all(16), children: [
            Rise(
              child: Row(children: [
                Expanded(child: Text('Salam, ${_me.fullName.split(' ').first}', style: Theme.of(context).textTheme.headlineSmall)),
                const Sticker('books', size: 48, angle: 6),
              ]),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place_rounded, size: 18, color: AppColors.teal),
              const SizedBox(width: 4),
              Expanded(child: Text('Teachers near $where', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 14),
            Rise(delayMs: 40, child: ParentMapSection(profile: _me, sample: useSample, refreshToken: widget.refreshToken)),
            const SizedBox(height: 14),
            Rise(
              delayMs: 80,
              child: TeacherBannerWidget(people: [for (final l in real) PortraitSource(name: l.name, url: l.avatarUrl)]),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search by subject, grade, curriculum, or teacher name...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            QuickCategoryRow(
              filters: _f,
              onPick: (q) {
                // Tapping the active pill again clears it; otherwise it becomes the only category filter.
                final wasOn = _f.isQuick(q);
                _f.cats
                  ..clear()
                  ..addAll(wasOn ? const <String>[] : q.slugs);
                _applyFilters(scroll: !wasOn);
              },
            ),
            const SizedBox(height: 12),
            SearchFilterBar(filters: _f, onChanged: _applyFilters),
            if (!_f.any)
              FutureBuilder<List<TeacherListing>>(
                future: _featuredFuture,
                builder: (context, fs) {
                  final online = useSample ? shownSampleOnline(source) : (fs.data ?? const <TeacherListing>[]);
                  if (online.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FeaturedOnlineSection(
                      listings: online,
                      connectingId: _connectingId,
                      onConnect: _connect,
                      onSeeAll: () {
                        _f.modes
                          ..clear()
                          ..add(TeachMode.online);
                        _applyFilters(scroll: true);
                      },
                    ),
                  );
                },
              ),
            if (done && !snap.hasError && !hasDistances && !useSample)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _Hint(icon: Icons.my_location_rounded, text: 'Save your current location in Account > Address to see teachers sorted by distance.'),
              ),
            if (useSample)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _Hint(icon: Icons.info_outline_rounded, text: 'No verified teachers yet. These are sample profiles so you can see how the board will look.'),
              ),
            const SizedBox(height: 16),
            SizedBox(key: _resultsKey, height: 0),
            if (!done)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.teal)))
            else if (snap.hasError)
              Text(errorText(snap.error!), style: const TextStyle(color: AppColors.coral))
            else ...[
              for (final (i, l) in shown.indexed)
                Rise(
                  delayMs: i * 60,
                  child: TeacherCard(
                    listing: l,
                    connecting: _connectingId == l.teacher.id,
                    onConnect: () => _connect(l),
                    onBook: () => _book(l),
                  ),
                ),
              if (shown.isEmpty)
                StickerEmpty(
                  sticker: 'pencil',
                  title: 'No teachers match yet',
                  hint: _f.any ? 'Try removing a filter.' : 'Try another subject or area.',
                ),
            ],
          ]);
        },
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppColors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

/// Sample teachers that teach online, shown in the featured carousel while no real teachers exist yet.
List<TeacherListing> shownSampleOnline(List<TeacherListing> source) => source.where((l) => l.teacher.teachesOnline).toList();
