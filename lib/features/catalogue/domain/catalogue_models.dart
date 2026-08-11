import '../../../core/services/app_environment.dart';

/// Resolves an image to a displayable URL.
///
/// Content carries either an uploaded asset key (served by the Worker from R2)
/// or an external link. Callers should not care which, so the choice is made
/// here rather than in every widget.
String? resolveMediaUrl({String? imageKey, String? imageUrl}) {
  final key = imageKey?.trim() ?? '';
  if (key.isNotEmpty) {
    final base = AppEnvironmentConfig.apiBaseUrl;
    return base.isEmpty ? null : '$base/api/media/$key';
  }
  final url = imageUrl?.trim() ?? '';
  return url.isEmpty ? null : url;
}

String _text(Map<String, dynamic> map, String key) =>
    (map[key] as String?)?.trim() ?? '';

int _int(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

double? _double(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}');
}

bool _bool(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == true || value == 1 || value == '1' || value == 'true';
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item != null && '$item'.trim().isNotEmpty) '$item'.trim(),
    ];
  }
  return const [];
}

/// A flagship catalogue area, e.g. "International Trade & Investment".
class ProgrammeArea {
  const ProgrammeArea({
    required this.id,
    required this.slug,
    required this.code,
    required this.title,
    required this.tagline,
    required this.summary,
    required this.description,
    required this.programmeCount,
    this.imageUrl,
  });

  final String id;
  final String slug;
  final String code;
  final String title;
  final String tagline;
  final String summary;
  final String description;
  final int programmeCount;
  final String? imageUrl;

  factory ProgrammeArea.fromMap(Map<String, dynamic> map) => ProgrammeArea(
    id: _text(map, 'id'),
    slug: _text(map, 'slug'),
    code: _text(map, 'code'),
    title: _text(map, 'title'),
    tagline: _text(map, 'tagline'),
    summary: _text(map, 'summary'),
    description: _text(map, 'description'),
    programmeCount: _int(map, 'programme_count'),
    imageUrl: resolveMediaUrl(
      imageKey: map['image_key'] as String?,
      imageUrl: map['image_url'] as String?,
    ),
  );
}

/// A format of offering: certificate, masterclass, short course, short case.
class ProgrammeType {
  const ProgrammeType({
    required this.id,
    required this.slug,
    required this.title,
    required this.pluralTitle,
    required this.description,
  });

  final String id;
  final String slug;
  final String title;
  final String pluralTitle;
  final String description;

  String get label => pluralTitle.isEmpty ? title : pluralTitle;

  factory ProgrammeType.fromMap(Map<String, dynamic> map) => ProgrammeType(
    id: _text(map, 'id'),
    slug: _text(map, 'slug'),
    title: _text(map, 'title'),
    pluralTitle: _text(map, 'plural_title'),
    description: _text(map, 'description'),
  );
}

/// A published offering as the public catalogue shows it.
class CatalogueProgramme {
  const CatalogueProgramme({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.description,
    required this.level,
    required this.durationLabel,
    required this.deliveryMode,
    required this.language,
    required this.certificateAward,
    required this.eligibility,
    required this.whoShouldAttend,
    required this.learningOutcomes,
    required this.tuitionCurrency,
    required this.cpdPoints,
    required this.registrationOpen,
    required this.featured,
    required this.areaSlug,
    required this.areaTitle,
    required this.typeSlug,
    required this.typeTitle,
    this.imageUrl,
    this.startDate,
    this.applicationDeadline,
    this.tuitionAmount,
    this.tuitionNote = '',
    this.capacity,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String summary;
  final String description;
  final String level;
  final String durationLabel;
  final String deliveryMode;
  final String language;
  final String certificateAward;
  final String eligibility;
  final String whoShouldAttend;
  final List<String> learningOutcomes;
  final String tuitionCurrency;
  final int cpdPoints;
  final bool registrationOpen;
  final bool featured;
  final String areaSlug;
  final String areaTitle;
  final String typeSlug;
  final String typeTitle;
  final String? imageUrl;
  final String? startDate;
  final String? applicationDeadline;
  final double? tuitionAmount;
  final String tuitionNote;
  final int? capacity;

  /// Formatted tuition, or a clear statement when there is no fee recorded.
  String get tuitionLabel {
    final amount = tuitionAmount;
    if (amount == null || amount <= 0) return 'On application';
    final rounded = amount.round();
    final digits = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '$tuitionCurrency $buffer';
  }

  factory CatalogueProgramme.fromMap(Map<String, dynamic> map) =>
      CatalogueProgramme(
        id: _text(map, 'id'),
        slug: _text(map, 'slug'),
        title: _text(map, 'title'),
        subtitle: _text(map, 'subtitle'),
        summary: _text(map, 'summary'),
        description: _text(map, 'description'),
        level: _text(map, 'level'),
        durationLabel: _text(map, 'duration_label'),
        deliveryMode: _text(map, 'delivery_mode'),
        language: _text(map, 'language'),
        certificateAward: _text(map, 'certificate_award'),
        eligibility: _text(map, 'eligibility'),
        whoShouldAttend: _text(map, 'who_should_attend'),
        learningOutcomes: _stringList(map['learning_outcomes']),
        tuitionCurrency: _text(map, 'tuition_currency').isEmpty
            ? 'USD'
            : _text(map, 'tuition_currency'),
        cpdPoints: _int(map, 'cpd_points'),
        registrationOpen: _bool(map, 'registration_open'),
        featured: _bool(map, 'featured'),
        areaSlug: _text(map, 'area_slug'),
        areaTitle: _text(map, 'area_title'),
        typeSlug: _text(map, 'type_slug'),
        typeTitle: _text(map, 'type_title'),
        imageUrl: resolveMediaUrl(
          imageKey: map['image_key'] as String?,
          imageUrl: map['image_url'] as String?,
        ),
        startDate: (map['start_date'] as String?)?.trim(),
        applicationDeadline: (map['application_deadline'] as String?)?.trim(),
        tuitionAmount: _double(map, 'tuition_amount'),
        tuitionNote: _text(map, 'tuition_note'),
        capacity: map['capacity'] == null ? null : _int(map, 'capacity'),
      );
}

class ProgrammeLessonOutline {
  const ProgrammeLessonOutline({
    required this.id,
    required this.title,
    required this.lessonType,
    required this.durationMinutes,
    required this.summary,
    required this.isPreview,
  });

  final String id;
  final String title;
  final String lessonType;
  final int durationMinutes;
  final String summary;
  final bool isPreview;

  factory ProgrammeLessonOutline.fromMap(Map<String, dynamic> map) =>
      ProgrammeLessonOutline(
        id: _text(map, 'id'),
        title: _text(map, 'title'),
        lessonType: _text(map, 'lesson_type'),
        durationMinutes: _int(map, 'duration_minutes'),
        summary: _text(map, 'summary'),
        isPreview: _bool(map, 'is_preview'),
      );
}

class ProgrammeModuleOutline {
  const ProgrammeModuleOutline({
    required this.id,
    required this.number,
    required this.title,
    required this.summary,
    required this.durationLabel,
    required this.lessons,
  });

  final String id;
  final int number;
  final String title;
  final String summary;
  final String durationLabel;
  final List<ProgrammeLessonOutline> lessons;

  factory ProgrammeModuleOutline.fromMap(Map<String, dynamic> map) =>
      ProgrammeModuleOutline(
        id: _text(map, 'id'),
        number: _int(map, 'number'),
        title: _text(map, 'title'),
        summary: _text(map, 'summary'),
        durationLabel: _text(map, 'duration_label'),
        lessons: [
          for (final lesson in (map['lessons'] as List? ?? const []))
            ProgrammeLessonOutline.fromMap(
              Map<String, dynamic>.from(lesson as Map),
            ),
        ],
      );
}

class FacultyProfile {
  const FacultyProfile({
    required this.id,
    required this.slug,
    required this.name,
    required this.roleTitle,
    required this.organisation,
    required this.bio,
    required this.expertise,
    this.imageUrl,
    this.linkedInUrl,
    this.programmeRole = '',
  });

  final String id;
  final String slug;
  final String name;
  final String roleTitle;
  final String organisation;
  final String bio;
  final List<String> expertise;
  final String? imageUrl;
  final String? linkedInUrl;
  final String programmeRole;

  factory FacultyProfile.fromMap(Map<String, dynamic> map) => FacultyProfile(
    id: _text(map, 'id'),
    slug: _text(map, 'slug'),
    name: _text(map, 'name'),
    roleTitle: _text(map, 'role_title'),
    organisation: _text(map, 'organisation'),
    bio: _text(map, 'bio'),
    expertise: _stringList(map['expertise']),
    imageUrl: resolveMediaUrl(
      imageKey: map['image_key'] as String?,
      imageUrl: map['image_url'] as String?,
    ),
    linkedInUrl: (map['linkedin_url'] as String?)?.trim(),
    programmeRole: _text(map, 'role'),
  );
}

class ProgrammeScheduleEntry {
  const ProgrammeScheduleEntry({
    required this.id,
    required this.title,
    required this.sessionType,
    required this.mode,
    required this.location,
    required this.timezone,
    required this.notes,
    this.startsAt,
    this.endsAt,
    this.facultyName = '',
    this.joinUrl,
  });

  final String id;
  final String title;
  final String sessionType;
  final String mode;
  final String location;
  final String timezone;
  final String notes;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String facultyName;
  final String? joinUrl;

  factory ProgrammeScheduleEntry.fromMap(Map<String, dynamic> map) =>
      ProgrammeScheduleEntry(
        id: _text(map, 'id'),
        title: _text(map, 'title'),
        sessionType: _text(map, 'session_type'),
        mode: _text(map, 'mode'),
        location: _text(map, 'location'),
        timezone: _text(map, 'timezone'),
        notes: _text(map, 'notes'),
        startsAt: DateTime.tryParse(_text(map, 'starts_at')),
        endsAt: DateTime.tryParse(_text(map, 'ends_at')),
        facultyName: _text(map, 'faculty_name'),
        joinUrl: (map['join_url'] as String?)?.trim(),
      );
}

/// Everything a public programme page needs, fetched in one request.
class ProgrammeDetail {
  const ProgrammeDetail({
    required this.programme,
    required this.modules,
    required this.faculty,
    required this.schedule,
  });

  final CatalogueProgramme programme;
  final List<ProgrammeModuleOutline> modules;
  final List<FacultyProfile> faculty;
  final List<ProgrammeScheduleEntry> schedule;

  int get totalLessons =>
      modules.fold(0, (sum, module) => sum + module.lessons.length);

  factory ProgrammeDetail.fromMap(Map<String, dynamic> map) => ProgrammeDetail(
    programme: CatalogueProgramme.fromMap(
      Map<String, dynamic>.from(map['programme'] as Map),
    ),
    modules: [
      for (final module in (map['modules'] as List? ?? const []))
        ProgrammeModuleOutline.fromMap(Map<String, dynamic>.from(module as Map)),
    ],
    faculty: [
      for (final member in (map['faculty'] as List? ?? const []))
        FacultyProfile.fromMap(Map<String, dynamic>.from(member as Map)),
    ],
    schedule: [
      for (final entry in (map['sessions'] as List? ?? const []))
        ProgrammeScheduleEntry.fromMap(Map<String, dynamic>.from(entry as Map)),
    ],
  );
}

/// The catalogue landing payload: areas, types and editable copy.
class CatalogueOverview {
  const CatalogueOverview({
    required this.areas,
    required this.types,
    required this.settings,
  });

  final List<ProgrammeArea> areas;
  final List<ProgrammeType> types;
  final Map<String, String> settings;

  String setting(String key, String fallback) {
    final value = settings[key]?.trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  factory CatalogueOverview.fromMap(Map<String, dynamic> map) =>
      CatalogueOverview(
        areas: [
          for (final area in (map['areas'] as List? ?? const []))
            ProgrammeArea.fromMap(Map<String, dynamic>.from(area as Map)),
        ],
        types: [
          for (final type in (map['types'] as List? ?? const []))
            ProgrammeType.fromMap(Map<String, dynamic>.from(type as Map)),
        ],
        settings: {
          for (final entry in (map['settings'] as Map? ?? const {}).entries)
            '${entry.key}': '${entry.value}',
        },
      );
}

/// An area with the programmes published inside it.
class AreaDetail {
  const AreaDetail({required this.area, required this.programmes});

  final ProgrammeArea area;
  final List<CatalogueProgramme> programmes;

  /// Programmes grouped by their type, in catalogue order.
  Map<String, List<CatalogueProgramme>> get byType {
    final grouped = <String, List<CatalogueProgramme>>{};
    for (final programme in programmes) {
      grouped.putIfAbsent(programme.typeTitle, () => []).add(programme);
    }
    return grouped;
  }

  factory AreaDetail.fromMap(Map<String, dynamic> map) => AreaDetail(
    area: ProgrammeArea.fromMap(Map<String, dynamic>.from(map['area'] as Map)),
    programmes: [
      for (final programme in (map['programmes'] as List? ?? const []))
        CatalogueProgramme.fromMap(Map<String, dynamic>.from(programme as Map)),
    ],
  );
}
