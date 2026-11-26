import '../core/constants.dart';

List<String> _strings(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? <String>[];
double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

class TeacherProfile {
  TeacherProfile({
    required this.id,
    this.bio,
    this.qualifications = const [],
    this.yearsExperience = 0,
    this.subjects = const [],
    this.curricula = const [],
    this.neighborhoods = const [],
    this.atSchool = false,
    this.monthlySalary,
    this.atStudentHome = false,
    this.currentSalary,
    this.rateType,
    this.rateAmount,
    this.atTeacherHome = false,
    this.verificationStatus = 'pending',
    this.cnicPath,
    this.degreePath,
    this.isAccepting = true,
    this.isStar = false,
    this.ratingAvg = 0,
    this.reviewsCount = 0,
    this.teachingModes = const [],
    this.isImmediatelyAvailable = false,
    this.expertiseCategories = const [],
  });

  final String id;
  final String? bio;
  final List<String> qualifications;
  final int yearsExperience;
  final List<String> subjects;
  final List<String> curricula;
  final List<String> neighborhoods;
  final bool atSchool;
  final double? monthlySalary;
  final bool atStudentHome;
  final bool atTeacherHome;
  final double? currentSalary; // PKR, current or most recent salary (optional)
  final RateType? rateType; // tuition fee is charged per day or per month
  final double? rateAmount; // PKR
  final String verificationStatus;
  final String? cnicPath;
  final String? degreePath;
  final bool isAccepting;
  final bool isStar;
  final double ratingAvg;
  final int reviewsCount;
  final List<String> teachingModes; // 'online' | 'home_academy' | 'private_home'
  final bool isImmediatelyAvailable;
  final List<String> expertiseCategories; // slugs, see kExpertise

  factory TeacherProfile.fromMap(Map<String, dynamic> m) => TeacherProfile(
        id: m['id'] as String,
        bio: m['bio_description'] as String?,
        qualifications: _strings(m['qualifications']),
        yearsExperience: (m['years_experience'] as num?)?.toInt() ?? 0,
        subjects: _strings(m['subjects']),
        curricula: _strings(m['curricula']),
        neighborhoods: _strings(m['neighborhoods']),
        atSchool: m['available_at_school'] == true,
        monthlySalary: _num(m['estimated_monthly_salary']),
        atStudentHome: m['available_at_student_home'] == true,
        atTeacherHome: m['available_at_teacher_home'] == true,
        currentSalary: _num(m['current_salary']),
        rateType: RateType.fromDb(m['rate_type'] as String?),
        rateAmount: _num(m['rate_amount']),
        verificationStatus: (m['verification_status'] as String?) ?? 'pending',
        cnicPath: m['cnic_doc_url'] as String?,
        degreePath: m['degree_doc_url'] as String?,
        isAccepting: m['is_accepting_students'] != false,
        isStar: m['is_star_teacher'] == true,
        ratingAvg: _num(m['rating_avg']) ?? 0,
        reviewsCount: (m['reviews_count'] as num?)?.toInt() ?? 0,
        teachingModes: _strings(m['teaching_modes']),
        isImmediatelyAvailable: m['is_immediately_available'] == true,
        expertiseCategories: _strings(m['expertise_categories']),
      );

  bool get teachesOnline => teachingModes.contains(TeachMode.online.db);
  int get activeModes => [atSchool, atStudentHome, atTeacherHome, teachesOnline].where((x) => x).length;
  bool get hasHomeTuition => atStudentHome || atTeacherHome;
  bool offers(TeachMode m) => teachingModes.contains(m.db);
  bool get isVerified => verificationStatus == 'verified';

  /// Onboarding counts as finished once the fields parents rely on are filled in.
  bool get isOnboardingComplete =>
      qualifications.isNotEmpty &&
      subjects.isNotEmpty &&
      curricula.isNotEmpty &&
      neighborhoods.isNotEmpty &&
      activeModes > 0;
}

class BookingRequest {
  BookingRequest({
    required this.id,
    required this.parentName,
    this.parentPhone,
    this.parentAddress,
    this.parentLocationLabel,
    this.parentLat,
    this.parentLng,
    this.grade,
    this.subject,
    required this.mode,
    this.neighborhood,
    this.schedule,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String parentName;
  final String? parentPhone; // phone, address and location are only filled in by the database once accepted
  final String? parentAddress;
  final String? parentLocationLabel;
  final double? parentLat;
  final double? parentLng;
  final String? grade;
  final String? subject;
  final String mode;
  final String? neighborhood;
  final String? schedule;
  final String? notes;
  final String status;
  final DateTime createdAt;

  factory BookingRequest.fromMap(Map<String, dynamic> m) => BookingRequest(
        id: m['id'] as String,
        parentName: (m['parent_name'] as String?) ?? 'Parent',
        parentPhone: m['parent_phone'] as String?,
        parentAddress: m['parent_address'] as String?,
        parentLocationLabel: m['parent_location_label'] as String?,
        parentLat: (m['parent_lat'] as num?)?.toDouble(),
        parentLng: (m['parent_lng'] as num?)?.toDouble(),
        grade: m['student_grade'] as String?,
        subject: m['subject'] as String?,
        mode: m['teaching_mode'] as String,
        neighborhood: m['neighborhood'] as String?,
        schedule: m['proposed_schedule'] as String?,
        notes: m['notes'] as String?,
        status: m['status'] as String,
        createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
      );
}
