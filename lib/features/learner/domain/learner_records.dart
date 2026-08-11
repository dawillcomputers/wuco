import 'learner_enums.dart';

class Assessment {
  const Assessment({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseTitle,
    required this.programmeTitle,
    required this.type,
    required this.status,
    required this.durationMinutes,
    this.dueDate,
    this.attemptsAllowed = 1,
    this.attemptsUsed = 0,
  });

  final String id;
  final String title;
  final String courseId;
  final String courseTitle;
  final String programmeTitle;
  final AssessmentType type;
  final AssessmentStatus status;
  final int durationMinutes;
  final DateTime? dueDate;
  final int attemptsAllowed;
  final int attemptsUsed;

  int get attemptsRemaining =>
      (attemptsAllowed - attemptsUsed).clamp(0, attemptsAllowed);

  /// Whole days until due; negative once overdue. Null when undated.
  int? get daysRemaining {
    final due = dueDate;
    if (due == null) return null;
    final now = DateTime.now();
    return DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }
}

class AssessmentResult {
  const AssessmentResult({
    required this.id,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.courseTitle,
    required this.date,
    required this.score,
    required this.maximumScore,
    required this.grade,
    required this.outcome,
    this.feedback,
    this.markedBy,
  });

  final String id;
  final String assessmentId;
  final String assessmentTitle;
  final String courseTitle;
  final DateTime date;
  final double score;
  final double maximumScore;
  final String grade;
  final ResultOutcome outcome;
  final String? feedback;
  final String? markedBy;

  double get percentage => maximumScore == 0 ? 0 : score / maximumScore;
  int get percentageRounded => (percentage * 100).round();
}

class Certificate {
  const Certificate({
    required this.id,
    required this.title,
    required this.programmeTitle,
    required this.status,
    required this.certificateNumber,
    this.issuedOn,
  });

  final String id;
  final String title;
  final String programmeTitle;
  final CertificateStatus status;
  final String certificateNumber;
  final DateTime? issuedOn;

  bool get isIssued => status == CertificateStatus.issued;
}

class Credential {
  const Credential({
    required this.id,
    required this.title,
    required this.issuer,
    required this.credentialId,
    required this.status,
    required this.issuedOn,
    this.expiresOn,
    this.skills = const [],
  });

  final String id;
  final String title;
  final String issuer;
  final String credentialId;
  final CredentialStatus status;
  final DateTime issuedOn;
  final DateTime? expiresOn;
  final List<String> skills;
}

class CpdRecord {
  const CpdRecord({
    required this.id,
    required this.title,
    required this.source,
    required this.points,
    required this.awardedOn,
  });

  final String id;
  final String title;
  final String source;
  final int points;
  final DateTime awardedOn;
}

/// CPD standing for a year. The target is supplied rather than hard-coded so
/// it can vary by learner or accrediting body.
class CpdSummary {
  const CpdSummary({
    required this.year,
    required this.pointsEarned,
    required this.pointsTarget,
    required this.records,
  });

  final int year;
  final int pointsEarned;
  final int pointsTarget;
  final List<CpdRecord> records;

  double get progress =>
      pointsTarget == 0 ? 0 : (pointsEarned / pointsTarget).clamp(0, 1);
  int get progressPercent => (progress * 100).round();
  int get pointsRemaining => (pointsTarget - pointsEarned).clamp(0, pointsTarget);
}

class LearnerNotification {
  const LearnerNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.read = false,
    this.actionRoute,
  });

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool read;
  final String? actionRoute;

  LearnerNotification copyWith({bool? read}) => LearnerNotification(
    id: id,
    title: title,
    message: message,
    category: category,
    createdAt: createdAt,
    read: read ?? this.read,
    actionRoute: actionRoute,
  );
}

class LearningActivity {
  const LearningActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.occurredAt,
  });

  final String id;
  final ActivityType type;
  final String title;
  final String detail;
  final DateTime occurredAt;
}

class UpcomingActivity {
  const UpcomingActivity({
    required this.id,
    required this.kind,
    required this.title,
    required this.context,
    required this.dueAt,
    this.actionRoute,
  });

  final String id;
  final UpcomingKind kind;
  final String title;
  final String context;
  final DateTime dueAt;
  final String? actionRoute;

  int get daysAway {
    final now = DateTime.now();
    return DateTime(dueAt.year, dueAt.month, dueAt.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  /// Deliberately calm phrasing; deadlines are stated, not alarmed about.
  String get relativeLabel => switch (daysAway) {
    < 0 => 'Overdue',
    0 => 'Today',
    1 => 'Tomorrow',
    final days when days < 7 => 'In $days days',
    _ => 'In ${(daysAway / 7).floor()} weeks',
  };
}

/// Headline figures for the dashboard.
class LearnerStats {
  const LearnerStats({
    required this.activeProgrammes,
    required this.coursesCompleted,
    required this.learningMinutes,
    required this.certificatesEarned,
    required this.cpdPoints,
    this.streakDays = 0,
  });

  final int activeProgrammes;
  final int coursesCompleted;
  final int learningMinutes;
  final int certificatesEarned;
  final int cpdPoints;
  final int streakDays;

  String get learningHoursLabel {
    final hours = learningMinutes ~/ 60;
    return hours == 0 ? '${learningMinutes}m' : '${hours}h';
  }
}

/// A hit from global search, kept transport-agnostic so the interface does not
/// change when a real index replaces the local one.
class LearnerSearchResult {
  const LearnerSearchResult({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String kind;
  final String route;
}
