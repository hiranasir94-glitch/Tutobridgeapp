import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'theme.dart';

/// State for a location: an editable, human-readable label plus optional GPS coordinates.
class LocationInput {
  LocationInput({String label = '', this.lat, this.lng}) : label = TextEditingController(text: label);
  final TextEditingController label;
  double? lat;
  double? lng;

  bool get hasCoords => lat != null && lng != null;
  String get text => label.text.trim();
  void dispose() => label.dispose();
}

class _LocError implements Exception {
  _LocError(this.message);
  final String message;
}

/// "Current location" field: type a label such as "Gulberg III, Lahore", or tap "Use Current Location" to capture
/// GPS coordinates and fill the label from them. Put it inside a [Form]; it validates like any form field.
class LocationField extends StatefulWidget {
  const LocationField({super.key, required this.input, this.label = 'Current location', this.requireCoordinates = false});
  final LocationInput input;
  final String label;

  /// When true, a typed label alone is not enough and GPS must be captured. Off by default so people whose
  /// device denies location can still sign up.
  final bool requireCoordinates;

  @override
  State<LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<LocationField> {
  bool _busy = false;
  String? _error;

  Future<String?> _reverse(double lat, double lng) async {
    try {
      final p = (await placemarkFromCoordinates(lat, lng)).firstOrNull;
      if (p == null) return null;
      final parts = <String>{
        for (final s in [p.subLocality, p.locality])
          if (s != null && s.trim().isNotEmpty) s.trim(),
      };
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null; // unsupported on web, or no network: the coordinates are used as the label instead
    }
  }

  Future<void> _locate() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw _LocError('Turn on location services on your device and try again.');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw _LocError('Location permission was denied. You can type your location instead.');
      if (perm == LocationPermission.deniedForever) throw _LocError('Location is blocked for this app. Allow it in your device settings, or type it instead.');

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      final label = await _reverse(pos.latitude, pos.longitude) ?? '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      if (!mounted) return;
      setState(() {
        widget.input.lat = pos.latitude;
        widget.input.lng = pos.longitude;
        widget.input.label.text = label; // still editable afterwards
      });
    } on _LocError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not get your location. Check that GPS is on and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: input.label,
        textCapitalization: TextCapitalization.words,
        maxLength: 120,
        decoration: InputDecoration(labelText: widget.label, hintText: 'e.g. Gulberg III, Lahore', counterText: ''),
        validator: (v) {
          if (v == null || v.trim().length < 3) return 'Enter your location or tap "Use Current Location"';
          if (widget.requireCoordinates && !input.hasCoords) return 'Tap "Use Current Location" to capture your GPS position';
          return null;
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _busy ? null : _locate,
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink))
            : const Icon(Icons.my_location_rounded),
        label: Text(_busy ? 'Finding you...' : 'Use Current Location'),
      ),
      if (input.hasCoords)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.ink),
            const SizedBox(width: 6),
            Expanded(
              child: Text('GPS saved (${input.lat!.toStringAsFixed(4)}, ${input.lng!.toStringAsFixed(4)})',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ]),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: AppColors.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}
