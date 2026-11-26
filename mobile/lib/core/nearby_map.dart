import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'theme.dart';

/// What a pin on the map stands for.
enum MapPinKind {
  teacher('Teacher', Icons.school_rounded, AppColors.lime),
  centre('Tuition centre / home tutor', Icons.home_work_rounded, AppColors.white),
  request('Looking for a teacher', Icons.person_search_rounded, AppColors.lime);

  const MapPinKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// One pin. The position is already snapped to a ~1 km grid by the database, so it is never an exact address.
class MapPin {
  const MapPin({required this.id, required this.kind, required this.title, required this.subtitle, required this.point, this.data = const {}});

  final String id;
  final MapPinKind kind;
  final String title;
  final String subtitle;
  final LatLng point;
  final Map<String, dynamic> data;
}

/// Lahore city centre, used when the user has not saved a location yet.
const kLahore = LatLng(31.5204, 74.3587);

/// A reusable map card: OpenStreetMap tiles, tappable pins, the user's own position, a legend and an expand button.
/// Used for teachers and centres on the parent home and for parent requests on the teacher home.
class NearbyMap extends StatelessWidget {
  const NearbyMap({
    super.key,
    required this.pins,
    required this.onPinTap,
    this.me,
    this.height = 230,
    this.legend = const [MapPinKind.teacher, MapPinKind.centre],
    this.allowExpand = true,
    this.emptyText = 'Nothing to show nearby yet.',
  });

  final List<MapPin> pins;
  final ValueChanged<MapPin> onPinTap;
  final LatLng? me;
  final double? height;
  final List<MapPinKind> legend;
  final bool allowExpand;
  final String emptyText;

  void _expand(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: NearbyMap(pins: pins, onPinTap: onPinTap, me: me, height: null, legend: legend, allowExpand: false, emptyText: emptyText),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final p in pins) p.point, if (me != null) me!];
    final fit = points.length >= 2
        ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(44), maxZoom: 15)
        : null;

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: me ?? (pins.isNotEmpty ? pins.first.point : kLahore),
        initialZoom: 12,
        initialCameraFit: fit,
        minZoom: 9,
        maxZoom: 18,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.tutobridge.app'),
        MarkerLayer(markers: [
          if (me != null)
            Marker(
              point: me!,
              width: 26,
              height: 26,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
              ),
            ),
          for (final p in pins)
            Marker(
              point: p.point,
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () => onPinTap(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.kind.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 2.5),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Icon(p.kind.icon, color: AppColors.ink, size: 21),
                ),
              ),
            ),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(allowExpand ? 20 : 0),
      child: Stack(children: [
        Positioned.fill(child: map),
        if (pins.isEmpty)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(12)),
              child: Text(emptyText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        Positioned(
          left: 8,
          bottom: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (final k in legend)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(k.icon, size: 13, color: AppColors.ink),
                  const SizedBox(width: 4),
                  Text(k.label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
              if (me != null)
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 11, color: AppColors.ink),
                  SizedBox(width: 4),
                  Text('You', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
            ]),
          ),
        ),
        if (allowExpand)
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(tooltip: 'Expand map', icon: const Icon(Icons.open_in_full_rounded, size: 18), onPressed: () => _expand(context)),
            ),
          ),
      ]),
    );

    return height == null ? card : SizedBox(height: height, child: card);
  }
}
