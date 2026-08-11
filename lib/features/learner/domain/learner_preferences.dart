import 'learner_profile.dart';

/// Settings a learner controls for themselves.
///
/// Deliberately holds nothing that confers entitlement — progress, grades,
/// certificates and CPD *points* are set by the backend, never from here. The
/// CPD *target* is included because it is a personal goal, not an award.
class LearnerPreferences {
  const LearnerPreferences({
    this.emailNotifications = true,
    this.assessmentReminders = true,
    this.resultAlerts = true,
    this.programmeAnnouncements = true,
    this.networkUpdates = false,
    this.visibility = ProfileVisibility.network,
    this.showCredentialsPublicly = true,
    this.autoplayNextLesson = false,
    this.playbackSpeed = 1.0,
    this.captionsByDefault = false,
    this.reducedMotion = false,
    this.largerText = false,
    this.cpdAnnualTarget = 60,
  });

  // Notifications.
  final bool emailNotifications;
  final bool assessmentReminders;
  final bool resultAlerts;
  final bool programmeAnnouncements;
  final bool networkUpdates;

  // Privacy.
  final ProfileVisibility visibility;
  final bool showCredentialsPublicly;

  // Learning.
  final bool autoplayNextLesson;
  final double playbackSpeed;
  final bool captionsByDefault;

  // Accessibility.
  final bool reducedMotion;
  final bool largerText;

  /// The learner's own CPD goal for the year. Configurable rather than fixed,
  /// since accrediting bodies differ.
  final int cpdAnnualTarget;

  static const playbackSpeeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];

  LearnerPreferences copyWith({
    bool? emailNotifications,
    bool? assessmentReminders,
    bool? resultAlerts,
    bool? programmeAnnouncements,
    bool? networkUpdates,
    ProfileVisibility? visibility,
    bool? showCredentialsPublicly,
    bool? autoplayNextLesson,
    double? playbackSpeed,
    bool? captionsByDefault,
    bool? reducedMotion,
    bool? largerText,
    int? cpdAnnualTarget,
  }) => LearnerPreferences(
    emailNotifications: emailNotifications ?? this.emailNotifications,
    assessmentReminders: assessmentReminders ?? this.assessmentReminders,
    resultAlerts: resultAlerts ?? this.resultAlerts,
    programmeAnnouncements:
        programmeAnnouncements ?? this.programmeAnnouncements,
    networkUpdates: networkUpdates ?? this.networkUpdates,
    visibility: visibility ?? this.visibility,
    showCredentialsPublicly:
        showCredentialsPublicly ?? this.showCredentialsPublicly,
    autoplayNextLesson: autoplayNextLesson ?? this.autoplayNextLesson,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    captionsByDefault: captionsByDefault ?? this.captionsByDefault,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    largerText: largerText ?? this.largerText,
    cpdAnnualTarget: cpdAnnualTarget ?? this.cpdAnnualTarget,
  );
}
