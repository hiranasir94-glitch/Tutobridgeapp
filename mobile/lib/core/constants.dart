enum UserRole {
  parent('parent'),
  teacher('teacher'),
  admin('admin');

  const UserRole(this.db);
  final String db;

  static UserRole? fromDb(String? v) {
    for (final r in UserRole.values) {
      if (r.db == v) return r;
    }
    return null;
  }
}

enum TeachingMode {
  atSchool('at_school', 'At School'),
  atStudentHome('at_student_home', "At Student's Home"),
  atTeacherHome('at_teacher_home', "At Teacher's Home"),
  online('online', 'Online');

  const TeachingMode(this.db, this.label);
  final String db;
  final String label;

  static TeachingMode? fromDb(String? v) {
    for (final m in TeachingMode.values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

/// The three teaching modes teachers pick on registration (teacher_profiles.teaching_modes).
/// homeAcademy and privateHome mirror the older available_at_teacher_home / available_at_student_home flags.
enum TeachMode {
  online('online', 'Online', 'Online'),
  homeAcademy('home_academy', 'Home Academy / Tuition Center', 'Home Academy'),
  privateHome('private_home', 'Private Home Tuition', 'Private Home Tuition');

  const TeachMode(this.db, this.label, this.badge);
  final String db;
  final String label;

  /// Short text for badges on tutor cards.
  final String badge;

  static TeachMode? fromDb(String? v) {
    for (final m in TeachMode.values) {
      if (m.db == v) return m;
    }
    return null;
  }
}

/// A level / specialty a teacher can cover (teacher_profiles.expertise_categories stores [slug]).
class ExpertiseCategory {
  const ExpertiseCategory(this.slug, this.label, this.short, [this.hint]);
  final String slug;
  final String label;

  /// Short name for chips.
  final String short;
  final String? hint;
}

const kExpertise = [
  ExpertiseCategory('early_years', 'Early Years', 'Early Years', 'Pre-K / Montessori / Kindergarten'),
  ExpertiseCategory('primary', 'Primary / Elementary (Grades 1–5)', 'Primary', 'Foundational Math, English, Science, Urdu'),
  ExpertiseCategory('middle_school', 'Middle School (Grades 6–8)', 'Middle School', 'Pre-Algebra, General Science, Languages, Social Studies'),
  ExpertiseCategory('high_school', 'High School / O-Levels / Matric (Grades 9–10)', 'O-Levels / Matric',
      'Subject-specific coaching (Physics, Chemistry, Biology, Accounting, Computer Science, Add Math)'),
  ExpertiseCategory('higher_secondary', 'Higher Secondary / A-Levels / FSc / IB (Grades 11–12)', 'A-Levels / FSc / IB',
      'Specialized exam prep and university-track subjects'),
  ExpertiseCategory('university_test_prep', 'University & Test Prep', 'Test Prep', 'Undergraduate courses, SAT, GRE, IELTS, MDCAT, ECAT'),
  ExpertiseCategory('quran_nazra', 'Quran / Nazra', 'Quran / Nazra'),
  ExpertiseCategory('sports', 'Sports', 'Sports'),
  ExpertiseCategory('aitchison_prep', 'Aitchison Preparatory', 'Aitchison Prep'),
];

ExpertiseCategory? expertiseBySlug(String slug) {
  for (final c in kExpertise) {
    if (c.slug == slug) return c;
  }
  return null;
}

/// Quick-tap category pills on the home page. Each one filters the search by one or more expertise slugs.
class QuickCategory {
  const QuickCategory(this.label, this.slugs);
  final String label;
  final List<String> slugs;
}

const kQuickCategories = [
  QuickCategory('Early Years', ['early_years']),
  QuickCategory('Primary', ['primary']),
  QuickCategory('Middle School', ['middle_school']),
  QuickCategory('O / A Levels', ['high_school', 'higher_secondary']),
  QuickCategory('Aitchison Prep', ['aitchison_prep']),
  QuickCategory('Quran / Nazra', ['quran_nazra']),
  QuickCategory('Test Prep', ['university_test_prep']),
  QuickCategory('Sports', ['sports']),
];

/// How a teacher charges for home tuition: a fee per day or per month (no per-hour pricing).
enum RateType {
  perDay('per_day', 'Per Day', 'day'),
  perMonth('per_month', 'Per Month', 'month');

  const RateType(this.db, this.label, this.unit);
  final String db;
  final String label;
  final String unit;

  static RateType? fromDb(String? v) {
    for (final r in RateType.values) {
      if (r.db == v) return r;
    }
    return null;
  }
}

const kCurricula = ['Montessori/Early Years', 'Primary', 'Matric/FSc', 'O Levels', 'A Levels', 'IB'];

const kSubjects = [
  'Mathematics', 'English', 'Urdu', 'Science', 'Physics', 'Chemistry', 'Biology',
  'Computer Science', 'Islamiat', 'Art & Crafts',
];

const kNeighborhoods = [
  'DHA', 'Gulberg', 'Johar Town', 'Jubilee Town', 'Model Town', 'Bahria Town', 'Cantt', 'Garden Town', 'Wapda Town',
];

/// Accepts 03XX XXXXXXX, +92 3XX XXXXXXX and 92 3XX XXXXXXX.
bool isValidPkMobile(String raw) {
  final s = raw.replaceAll(RegExp(r'[\s-]'), '');
  return RegExp(r'^(\+92|92|0)3\d{9}$').hasMatch(s);
}

/// Digits only, with Pakistan's country code, for wa.me links.
String toInternational(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('92')) return d;
  if (d.startsWith('0')) return '92${d.substring(1)}';
  return '92$d';
}
