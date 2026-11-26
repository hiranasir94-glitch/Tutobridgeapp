import '../core/constants.dart';

class AppProfile {
  AppProfile({
    required this.id,
    required this.role,
    required this.fullName,
    this.phone,
    this.city,
    this.avatarUrl,
    this.address,
    this.locationLabel,
    this.lat,
    this.lng,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String? phone;
  final String? city;
  final String? avatarUrl;
  final String? address; // residential address (parent) or current address (teacher)
  final String? locationLabel; // human-readable current location
  final double? lat;
  final double? lng;

  factory AppProfile.fromMap(Map<String, dynamic> m) => AppProfile(
        id: m['id'] as String,
        role: UserRole.fromDb(m['role'] as String?) ?? UserRole.parent,
        fullName: (m['full_name'] as String?) ?? '',
        phone: m['phone_number'] as String?,
        city: m['city'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        address: m['address'] as String?,
        locationLabel: m['current_location_label'] as String?,
        lat: (m['current_lat'] as num?)?.toDouble(),
        lng: (m['current_lng'] as num?)?.toDouble(),
      );
}
