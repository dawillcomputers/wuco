/// Status of a learner's place on a programme.
enum ProgrammeStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  awaitingAssessment('Awaiting assessment'),
  certificateAvailable('Certificate available'),
  completed('Completed'),
  expired('Expired'),
  suspended('Suspended');

  const ProgrammeStatus(this.label);
  final String label;

  /// Paired with colour everywhere it appears, so status is never carried by
  /// colour alone.
  String get iconName => switch (this) {
    ProgrammeStatus.notStarted => 'schedule',
    ProgrammeStatus.inProgress => 'play',
    ProgrammeStatus.awaitingAssessment => 'hourglass',
    ProgrammeStatus.certificateAvailable => 'award',
    ProgrammeStatus.completed => 'check',
    ProgrammeStatus.expired => 'expired',
    ProgrammeStatus.suspended => 'blocked',
  };
}

enum CourseStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  assessmentPending('Assessment pending'),
  certificateEligible('Certificate eligible'),
  completed('Completed');

  const CourseStatus(this.label);
  final String label;
}

/// Content types the learning interface is prepared to render.
enum LessonType {
  video('Video'),
  text('Reading'),
  pdf('PDF'),
  presentation('Presentation'),
  audio('Audio'),
  externalResource('External resource'),
  quiz('Quiz'),
  assignment('Assignment'),
  caseStudy('Case study'),
  liveSession('Live session');

  const LessonType(this.label);
  final String label;
}

enum LessonState {
  locked,
  available,
  inProgress,
  completed;

  bool get isOpenable => this != LessonState.locked;
}

enum AssessmentType {
  quiz('Quiz'),
  finalExamination('Final examination'),
  caseStudy('Case study'),
  executiveAssignment('Executive assignment'),
  capstone('Capstone');

  const AssessmentType(this.label);
  final String label;
}

enum AssessmentStatus {
  upcoming('Upcoming'),
  available('Available'),
  submitted('Submitted'),
  marking('Being marked'),
  completed('Completed'),
  missed('Missed');

  const AssessmentStatus(this.label);
  final String label;
}

enum ResultOutcome {
  passed('Passed'),
  failed('Not passed'),
  pending('Pending');

  const ResultOutcome(this.label);
  final String label;
}

enum CertificateStatus {
  issued('Issued'),
  pending('Pending'),
  revoked('Revoked');

  const CertificateStatus(this.label);
  final String label;
}

enum CredentialStatus {
  active('Active'),
  expired('Expired'),
  revoked('Revoked');

  const CredentialStatus(this.label);
  final String label;
}

enum NotificationCategory {
  course('Course'),
  assessment('Assessment'),
  result('Result'),
  certificate('Certificate'),
  programme('Programme'),
  system('System'),
  event('Event'),
  professionalNetwork('Professional Network'),
  aiMentor('AI Mentor');

  const NotificationCategory(this.label);
  final String label;
}

enum ActivityType {
  courseAccessed('Course accessed'),
  lessonCompleted('Lesson completed'),
  assessmentSubmitted('Assessment submitted'),
  certificateEarned('Certificate earned'),
  cpdUpdated('CPD updated'),
  programmeEnrolled('Programme enrolled');

  const ActivityType(this.label);
  final String label;
}

enum UpcomingKind {
  assessment('Assessment'),
  liveClass('Live class'),
  milestone('Programme milestone'),
  certificate('Certificate'),
  event('Event');

  const UpcomingKind(this.label);
  final String label;
}

/// Filters offered on the course list.
enum CourseFilter {
  all('All'),
  inProgress('In progress'),
  notStarted('Not started'),
  completed('Completed'),
  assessmentPending('Assessment pending'),
  certificateEligible('Certificate eligible');

  const CourseFilter(this.label);
  final String label;

  bool matches(CourseStatus status) => switch (this) {
    CourseFilter.all => true,
    CourseFilter.inProgress => status == CourseStatus.inProgress,
    CourseFilter.notStarted => status == CourseStatus.notStarted,
    CourseFilter.completed => status == CourseStatus.completed,
    CourseFilter.assessmentPending => status == CourseStatus.assessmentPending,
    CourseFilter.certificateEligible =>
      status == CourseStatus.certificateEligible,
  };
}
