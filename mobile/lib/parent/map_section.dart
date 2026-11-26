import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import '../core/nearby_map.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';
import 'request_sheet.dart';

/// The map at the top of the parent home: verified teachers and tuition centres around the parent's saved location.
/// Positions come from map_teachers(), which snaps them to a ~1 km grid, so no exact address is ever shown.
class ParentMapSection extends StatefulWidget {
  const ParentMapSection({super.key, required this.profile, this.sample = false, this.refreshToken = 0});
  final AppProfile profile;

  /// Show built-in sample pins (used while there are no verified teachers yet).
  final bool sample;
  final int refreshToken;

  @override
  State<ParentMapSection> createState() => _ParentMapSectionState();
}

class _ParentMapSectionState extends State<ParentMapSection> {
  late Future<List<MapPin>> _future = _load();

  @override
  void didUpdateWidget(covariant ParentMapSection old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken || old.sample != widget.sample || old.profile.lat != widget.profile.lat) {
      setState(() => _future = _load());
    }
  }

  LatLng? get _me => (widget.profile.lat != null && widget.profile.lng != null) ? LatLng(widget.profile.lat!, widget.profile.lng!) : null;

  Future<List<MapPin>> _load() async {
    if (widget.sample) return _samplePins();
    final rows = await supabase.rpc('map_teachers') as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final kind = m['kind'] == 'centre' ? MapPinKind.centre : MapPinKind.teacher;
      final subjects = List<String>.from((m['subjects'] as List?) ?? const []);
      final km = double.tryParse('${m['distance_km']}');
      return MapPin(
        id: '${m['teacher_id']}',
        kind: kind,
        title: '${m['name']}',
        subtitle: [if (subjects.isNotEmpty) subjects.take(3).join(', '), if (km != null) (km < 1 ? 'Under 1 km away' : 'About $km km away')].join(' · '),
        point: LatLng(double.parse('${m['lat']}'), double.parse('${m['lng']}')),
        data: {'star': m['is_star'] == true, 'rating': m['rating'], 'curricula': m['curricula']},
      );
    }).toList();
  }

  List<MapPin> _samplePins() => const [
        MapPin(id: 'sample-1', kind: MapPinKind.teacher, title: 'Sample Teacher A', subtitle: 'Mathematics, Physics', point: LatLng(31.4755, 74.3968)),
        MapPin(id: 'sample-2', kind: MapPinKind.centre, title: 'Sample Tuition Centre', subtitle: 'English, Urdu', point: LatLng(31.4679, 74.2751)),
        MapPin(id: 'sample-3', kind: MapPinKind.teacher, title: 'Sample Teacher B', subtitle: 'Chemistry, Biology', point: LatLng(31.5301, 74.3702)),
      ];

  Future<void> _connect(MapPin p) async {
    if (widget.sample || p.id.startsWith('sample-')) {
      showSnack(context, 'This is a sample pin. Real teachers will appear here once they are verified.');
      return;
    }
    try {
      final id = await supabase.rpc('start_conversation', params: {'p_teacher_id': p.id}) as String;
      if (!mounted) return;
      Navigator.of(context).pop(); // close the pin sheet
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, otherName: p.title)));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  void _openPin(MapPin p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(backgroundColor: p.kind.color, child: Icon(p.kind.icon, color: AppColors.ink)),
              const SizedBox(width: 12),
              Expanded(child: Text(p.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              if (p.data['star'] == true) const Pill('Star Teacher', color: AppColors.ink, background: AppColors.lime),
            ]),
            const SizedBox(height: 8),
            Text(p.kind.label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            if (p.subtitle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.subtitle)),
            const SizedBox(height: 4),
            const Text('Location shown is approximate.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _connect(p), icon: const Icon(Icons.chat_bubble_rounded), label: const Text('Connect'))),
          ]),
        ),
      ),
    );
  }

  void _post() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => TuitionRequestSheet(hasLocation: _me != null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Teachers & tuition centres near you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        TextButton.icon(onPressed: _post, icon: const Icon(Icons.add_location_alt_rounded, size: 18), label: const Text('Post a request')),
      ]),
      FutureBuilder<List<MapPin>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 230, child: Center(child: CircularProgressIndicator(color: AppColors.ink)));
          }
          if (snap.hasError) {
            return Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text(errorText(snap.error!), style: const TextStyle(color: AppColors.ink)),
            );
          }
          return NearbyMap(
            pins: snap.data ?? const [],
            me: _me,
            onPinTap: _openPin,
            emptyText: 'No teachers on the map yet. Check back soon.',
          );
        },
      ),
    ]);
  }
}
