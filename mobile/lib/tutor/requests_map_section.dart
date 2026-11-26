import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../chat/chat_screen.dart';
import '../core/nearby_map.dart';
import '../core/supabase.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../models/app_profile.dart';

/// The map at the top of the teacher home: parents and students nearby who are looking for a teacher.
/// Positions come from map_requests() (snapped to ~1 km, first name only). Connecting opens a chat with the parent.
class TutorMapSection extends StatefulWidget {
  const TutorMapSection({super.key, required this.profile, required this.verified});
  final AppProfile profile;
  final bool verified;

  @override
  State<TutorMapSection> createState() => _TutorMapSectionState();
}

class _TutorMapSectionState extends State<TutorMapSection> {
  late Future<List<MapPin>> _future = _load();

  LatLng? get _me => (widget.profile.lat != null && widget.profile.lng != null) ? LatLng(widget.profile.lat!, widget.profile.lng!) : null;

  Future<List<MapPin>> _load() async {
    final rows = await supabase.rpc('map_requests') as List;
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final km = double.tryParse('${m['distance_km']}');
      final bits = [
        '${m['subject']}',
        if (m['grade'] != null) '${m['grade']}',
        if (m['curriculum'] != null) '${m['curriculum']}',
      ];
      return MapPin(
        id: '${m['request_id']}',
        kind: MapPinKind.request,
        title: '${m['parent_first_name']} is looking for a teacher',
        subtitle: bits.join(' · '),
        point: LatLng(double.parse('${m['lat']}'), double.parse('${m['lng']}')),
        data: {
          'name': '${m['parent_first_name']}',
          'area': m['area'],
          'note': m['note'],
          'km': km,
        },
      );
    }).toList();
  }

  Future<void> _connect(MapPin p) async {
    try {
      final id = await supabase.rpc('connect_to_request', params: {'p_request_id': p.id}) as String;
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, otherName: '${p.data['name']}')));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  void _openPin(MapPin p) {
    final km = p.data['km'] as double?;
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
              Expanded(child: Text(p.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            Text(p.subtitle, style: const TextStyle(fontWeight: FontWeight.w700)),
            if ((p.data['area'] as String?)?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Area: ${p.data['area']}')),
            if (km != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(km < 1 ? 'Under 1 km from you' : 'About $km km from you')),
            if ((p.data['note'] as String?)?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 8), child: Text('"${p.data['note']}"')),
            const SizedBox(height: 4),
            const Text('Location shown is approximate. Contact details are shared only after a booking is accepted.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => _connect(p), icon: const Icon(Icons.chat_bubble_rounded), label: const Text('Connect'))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Parents looking for teachers near you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        IconButton(tooltip: 'Refresh', onPressed: () => setState(() => _future = _load()), icon: const Icon(Icons.refresh_rounded, size: 20)),
      ]),
      if (!widget.verified)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
          child: const Text('Requests on the map appear once your profile is verified.', style: TextStyle(fontSize: 13)),
        ),
      if (_me == null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(12)),
          child: const Text('Save your current location in Account > Address to see how far each request is.', style: TextStyle(fontSize: 13)),
        ),
      FutureBuilder<List<MapPin>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 230, child: Center(child: CircularProgressIndicator(color: AppColors.ink)));
          }
          if (snap.hasError) {
            return Text(errorText(snap.error!), style: const TextStyle(color: AppColors.ink));
          }
          final pins = snap.data ?? const <MapPin>[];
          return NearbyMap(
            pins: pins,
            me: _me,
            legend: const [MapPinKind.request],
            onPinTap: _openPin,
            emptyText: 'No open requests nearby right now.',
          );
        },
      ),
    ]);
  }
}
