import 'teacher_profile.dart';

/// A teacher as shown on the discovery board: the teacher row plus the name and picture from profiles.
class TeacherListing {
  TeacherListing(this.teacher, this.name, this.avatarUrl, {this.distanceKm, this.isSample = false});

  final TeacherProfile teacher;
  final String name;
  final String? avatarUrl;

  /// Approximate distance from the parent's saved location (rounded by the database to 0.5 km).
  final double? distanceKm;

  /// True for the built-in demo profiles shown when there are no real teachers yet.
  final bool isSample;

  TeacherListing withDistance(double? km) => TeacherListing(teacher, name, avatarUrl, distanceKm: km, isSample: isSample);
}
