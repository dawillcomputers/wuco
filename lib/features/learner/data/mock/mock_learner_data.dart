import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_note.dart';
import '../../domain/learner_preferences.dart';
import '../../domain/learner_profile.dart';
import '../../domain/learner_programme.dart';
import '../../domain/learner_records.dart';

/// Seed data for the offline learner backend.
///
/// It lives here — never in a widget — so replacing it with a real API is a
/// change of repository implementation only. The store is mutable so lesson
/// completion behaves realistically within a session.
class MockLearnerStore {
  MockLearnerStore() {
    _programmes = _seedProgrammes();
    _courses = _seedCourses();
    _assessments = _seedAssessments();
    _results = _seedResults();
    _certificates = _seedCertificates();
    _credentials = _seedCredentials();
    _cpd = _seedCpd();
    _notifications = _seedNotifications();
    _activity = _seedActivity();
    _upcoming = _seedUpcoming();
    _notes = _seedNotes();
  }

  late List<LearnerProgramme> _programmes;
  late List<LearnerCourse> _courses;
  late List<Assessment> _assessments;
  late List<AssessmentResult> _results;
  late List<Certificate> _certificates;
  late List<Credential> _credentials;
  late CpdSummary _cpd;
  late List<LearnerNotification> _notifications;
  late List<LearningActivity> _activity;
  late List<UpcomingActivity> _upcoming;
  late List<LessonNote> _notes;

  var _profile = const LearnerProfile(
    userId: 'me',
    professionalTitle: 'Director of Strategy',
    organisation: 'Continental Development Partners',
    bio:
        'Executive focused on regional integration, investment readiness and '
        'institutional reform across West and East Africa.',
    expertise: ['Regional integration', 'Investment strategy', 'Governance'],
    city: 'Accra',
  );

  var _preferences = const LearnerPreferences();

  String? _mostRecentCourseId = 'course-finance';

  List<LearnerProgramme> get programmes => List.unmodifiable(_programmes);
  List<LearnerCourse> get courses => List.unmodifiable(_courses);
  List<Assessment> get assessments => List.unmodifiable(_assessments);
  List<AssessmentResult> get results => List.unmodifiable(_results);
  List<Certificate> get certificates => List.unmodifiable(_certificates);
  List<Credential> get credentials => List.unmodifiable(_credentials);
  CpdSummary get cpd => _cpd;
  List<LearnerNotification> get notifications => List.unmodifiable(_notifications);
  List<LearningActivity> get activity => List.unmodifiable(_activity);
  List<UpcomingActivity> get upcoming => List.unmodifiable(_upcoming);
  List<LessonNote> get notes => List.unmodifiable(_notes);
  LearnerProfile get profile => _profile;
  LearnerPreferences get preferences => _preferences;
  String? get mostRecentCourseId => _mostRecentCourseId;

  LearnerCourse? courseById(String id) {
    for (final course in _courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  Lesson? lessonById(String courseId, String lessonId) {
    for (final lesson in courseById(courseId)?.lessons ?? const <Lesson>[]) {
      if (lesson.id == lessonId) return lesson;
    }
    return null;
  }

  List<Lesson> get bookmarkedLessons => [
    for (final course in _courses)
      for (final lesson in course.lessons)
        if (lesson.bookmarked) lesson,
  ];

  LearnerProfile saveProfile(LearnerProfile profile) => _profile = profile;

  LearnerPreferences savePreferences(LearnerPreferences preferences) {
    _preferences = preferences;
    // The learner's CPD goal lives in preferences but is reported through the
    // CPD summary, so the two are kept in step here rather than in a widget.
    _cpd = CpdSummary(
      year: _cpd.year,
      pointsEarned: _cpd.pointsEarned,
      pointsTarget: preferences.cpdAnnualTarget,
      records: _cpd.records,
    );
    return _preferences;
  }

  CpdSummary setCpdTarget(int points) {
    savePreferences(_preferences.copyWith(cpdAnnualTarget: points));
    return _cpd;
  }

  LessonNote saveNote({
    required String courseId,
    required String lessonId,
    required String body,
    String? noteId,
  }) {
    final existing = noteId == null
        ? -1
        : _notes.indexWhere((note) => note.id == noteId);
    if (existing != -1) {
      final updated = _notes[existing].copyWith(
        body: body,
        updatedAt: DateTime.now(),
      );
      _notes = [..._notes]..[existing] = updated;
      return updated;
    }
    final created = LessonNote(
      id: 'note-${DateTime.now().microsecondsSinceEpoch}',
      courseId: courseId,
      lessonId: lessonId,
      body: body,
      createdAt: DateTime.now(),
    );
    _notes = [created, ..._notes];
    return created;
  }

  void deleteNote(String noteId) =>
      _notes = [for (final note in _notes) if (note.id != noteId) note];

  void recordAccess(String courseId) => _mostRecentCourseId = courseId;

  /// Marks a lesson complete and unlocks the next one, mirroring the
  /// sequential unlocking the real backend will enforce.
  LearnerCourse completeLesson(String courseId, String lessonId) {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) throw StateError('Unknown course $courseId');
    final course = _courses[index];

    final flat = course.lessons;
    final position = flat.indexWhere((l) => l.id == lessonId);
    final nextId = position >= 0 && position + 1 < flat.length
        ? flat[position + 1].id
        : null;

    LearnerCourse updated = _rebuild(course, (lesson) {
      if (lesson.id == lessonId) {
        return lesson.copyWith(state: LessonState.completed);
      }
      if (lesson.id == nextId && lesson.state == LessonState.locked) {
        return lesson.copyWith(state: LessonState.available);
      }
      return lesson;
    });

    _courses[index] = updated;
    _activity = [
      LearningActivity(
        id: 'act-${DateTime.now().microsecondsSinceEpoch}',
        type: ActivityType.lessonCompleted,
        title: flat[position].title,
        detail: updated.title,
        occurredAt: DateTime.now(),
      ),
      ..._activity,
    ];
    return updated;
  }

  LearnerCourse setBookmark(String courseId, String lessonId, bool value) {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index == -1) throw StateError('Unknown course $courseId');
    final updated = _rebuild(
      _courses[index],
      (lesson) =>
          lesson.id == lessonId ? lesson.copyWith(bookmarked: value) : lesson,
    );
    _courses[index] = updated;
    return updated;
  }

  LearnerCourse _rebuild(LearnerCourse course, Lesson Function(Lesson) map) =>
      LearnerCourse(
        id: course.id,
        programmeId: course.programmeId,
        number: course.number,
        title: course.title,
        category: course.category,
        summary: course.summary,
        imageUrl: course.imageUrl,
        faculty: course.faculty,
        durationLabel: course.durationLabel,
        status: course.status,
        objectives: course.objectives,
        cpdPoints: course.cpdPoints,
        lastAccessed: course.lastAccessed,
        modules: [
          for (final module in course.modules)
            CourseModule(
              id: module.id,
              courseId: module.courseId,
              number: module.number,
              title: module.title,
              lessons: [for (final lesson in module.lessons) map(lesson)],
            ),
        ],
      );

  void markNotificationRead(String id) {
    _notifications = [
      for (final n in _notifications) n.id == id ? n.copyWith(read: true) : n,
    ];
  }

  void markAllNotificationsRead() {
    _notifications = [for (final n in _notifications) n.copyWith(read: true)];
  }

  // --- Seeds ---------------------------------------------------------------

  static const _imageFinance =
      'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1200&q=80';
  static const _imageLeadership =
      'https://images.unsplash.com/photo-1521737711867-e3b97375f902?auto=format&fit=crop&w=1200&q=80';
  static const _imageTrade =
      'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?auto=format&fit=crop&w=1200&q=80';
  static const _imagePolicy =
      'https://images.unsplash.com/photo-1526628953301-3e589a6a8b74?auto=format&fit=crop&w=1200&q=80';

  List<LearnerProgramme> _seedProgrammes() => [
    LearnerProgramme(
      id: 'prog-leadership',
      title: 'Executive Leadership & Governance',
      category: 'Leadership',
      summary:
          'Strengthen strategic judgement, board-level governance and the '
          'confidence to lead complex organisations.',
      imageUrl: _imageLeadership,
      durationLabel: '12 weeks',
      deliveryMode: 'Blended',
      status: ProgrammeStatus.inProgress,
      courseIds: const ['course-leadership', 'course-governance'],
      faculty: const ['Dr. Amina Yusuf', 'Prof. Kwame Mensah'],
      startDate: DateTime.now().subtract(const Duration(days: 38)),
      expectedCompletion: DateTime.now().add(const Duration(days: 46)),
      cpdPoints: 24,
    ),
    LearnerProgramme(
      id: 'prog-finance',
      title: 'Corporate Finance for Executives',
      category: 'Finance',
      summary:
          'Capital structure, valuation and investment decisions for leaders '
          'accountable for financial outcomes.',
      imageUrl: _imageFinance,
      durationLabel: '10 weeks',
      deliveryMode: 'Online',
      status: ProgrammeStatus.inProgress,
      courseIds: const ['course-finance'],
      faculty: const ['Dr. Nadia Okonkwo'],
      startDate: DateTime.now().subtract(const Duration(days: 21)),
      expectedCompletion: DateTime.now().add(const Duration(days: 49)),
      cpdPoints: 18,
    ),
    LearnerProgramme(
      id: 'prog-trade',
      title: 'Africa Trade & Investment',
      category: 'Trade',
      summary:
          'AfCFTA, regional integration and cross-border investment strategy '
          'for a continental market.',
      imageUrl: _imageTrade,
      durationLabel: '16 weeks',
      deliveryMode: 'Blended',
      status: ProgrammeStatus.certificateAvailable,
      courseIds: const ['course-trade'],
      faculty: const ['Prof. Selassie Bekele'],
      startDate: DateTime.now().subtract(const Duration(days: 190)),
      expectedCompletion: DateTime.now().subtract(const Duration(days: 14)),
      cpdPoints: 30,
      certificateId: 'cert-trade',
    ),
  ];

  List<LearnerCourse> _seedCourses() => [
    LearnerCourse(
      id: 'course-finance',
      programmeId: 'prog-finance',
      number: 1,
      title: 'Corporate Finance for Executives',
      category: 'Finance',
      summary:
          'Read financial statements with authority, evaluate investments and '
          'shape capital structure decisions.',
      imageUrl: _imageFinance,
      faculty: 'Dr. Nadia Okonkwo',
      durationLabel: '8 modules · 24h',
      status: CourseStatus.inProgress,
      cpdPoints: 18,
      lastAccessed: DateTime.now().subtract(const Duration(hours: 6)),
      objectives: const [
        'Interpret financial statements for executive decisions',
        'Evaluate investment appraisal techniques',
        'Assess capital structure and cost of capital',
      ],
      modules: _financeModules(),
    ),
    LearnerCourse(
      id: 'course-leadership',
      programmeId: 'prog-leadership',
      number: 1,
      title: 'Executive Leadership & Governance',
      category: 'Leadership',
      summary:
          'Lead with clarity under pressure, and govern with accountability at '
          'board level.',
      imageUrl: _imageLeadership,
      faculty: 'Dr. Amina Yusuf',
      durationLabel: '6 modules · 18h',
      status: CourseStatus.inProgress,
      cpdPoints: 14,
      lastAccessed: DateTime.now().subtract(const Duration(days: 2)),
      objectives: const [
        'Apply governance frameworks to real decisions',
        'Lead teams through organisational change',
      ],
      modules: _leadershipModules(),
    ),
    LearnerCourse(
      id: 'course-governance',
      programmeId: 'prog-leadership',
      number: 2,
      title: 'Board Governance & Risk',
      category: 'Governance',
      summary:
          'Risk oversight, board effectiveness and the duties of directors.',
      imageUrl: _imagePolicy,
      faculty: 'Prof. Kwame Mensah',
      durationLabel: '5 modules · 15h',
      status: CourseStatus.notStarted,
      cpdPoints: 10,
      objectives: const ['Evaluate board effectiveness', 'Oversee enterprise risk'],
      modules: _governanceModules(),
    ),
    LearnerCourse(
      id: 'course-trade',
      programmeId: 'prog-trade',
      number: 1,
      title: 'Africa Trade & Investment Strategy',
      category: 'Trade',
      summary:
          'Build cross-border strategy around AfCFTA and regional integration.',
      imageUrl: _imageTrade,
      faculty: 'Prof. Selassie Bekele',
      durationLabel: '6 modules · 20h',
      status: CourseStatus.completed,
      cpdPoints: 30,
      lastAccessed: DateTime.now().subtract(const Duration(days: 20)),
      objectives: const ['Assess AfCFTA opportunities', 'Structure cross-border deals'],
      modules: _tradeModules(),
    ),
  ];

  static List<CourseModule> _financeModules() => [
    CourseModule(
      id: 'mod-fin-1',
      courseId: 'course-finance',
      number: 1,
      title: 'Financial Statements for Executives',
      lessons: [
        _lesson('les-fin-1', 'mod-fin-1', 'course-finance',
            'Reading the balance sheet', LessonType.video, 18,
            LessonState.completed),
        _lesson('les-fin-2', 'mod-fin-1', 'course-finance',
            'Income and cash flow', LessonType.video, 22, LessonState.completed),
        _lesson('les-fin-3', 'mod-fin-1', 'course-finance',
            'Ratio analysis in practice', LessonType.text, 15,
            LessonState.completed),
      ],
    ),
    CourseModule(
      id: 'mod-fin-2',
      courseId: 'course-finance',
      number: 2,
      title: 'Investment Appraisal',
      lessons: [
        _lesson('les-fin-4', 'mod-fin-2', 'course-finance',
            'Net present value', LessonType.video, 20, LessonState.completed),
        _lesson('les-fin-5', 'mod-fin-2', 'course-finance',
            'Internal rate of return', LessonType.video, 19,
            LessonState.inProgress),
        _lesson('les-fin-6', 'mod-fin-2', 'course-finance',
            'Appraisal case study', LessonType.caseStudy, 45,
            LessonState.locked),
      ],
    ),
    CourseModule(
      id: 'mod-fin-3',
      courseId: 'course-finance',
      number: 3,
      title: 'Capital Structure & Valuation',
      lessons: [
        _lesson('les-fin-7', 'mod-fin-3', 'course-finance',
            'Cost of capital', LessonType.video, 24, LessonState.locked),
        _lesson('les-fin-8', 'mod-fin-3', 'course-finance',
            'Valuation approaches', LessonType.presentation, 30,
            LessonState.locked),
        _lesson('les-fin-9', 'mod-fin-3', 'course-finance',
            'Module quiz', LessonType.quiz, 20, LessonState.locked),
      ],
    ),
  ];

  static List<CourseModule> _leadershipModules() => [
    CourseModule(
      id: 'mod-lead-1',
      courseId: 'course-leadership',
      number: 1,
      title: 'Introduction to Executive Leadership',
      lessons: [
        _lesson('les-lead-1', 'mod-lead-1', 'course-leadership',
            'The executive mandate', LessonType.video, 16,
            LessonState.completed),
        _lesson('les-lead-2', 'mod-lead-1', 'course-leadership',
            'Leading beyond authority', LessonType.text, 14,
            LessonState.completed),
      ],
    ),
    CourseModule(
      id: 'mod-lead-2',
      courseId: 'course-leadership',
      number: 2,
      title: 'Strategic Decision Making',
      lessons: [
        _lesson('les-lead-3', 'mod-lead-2', 'course-leadership',
            'Decision quality under uncertainty', LessonType.video, 21,
            LessonState.available),
        _lesson('les-lead-4', 'mod-lead-2', 'course-leadership',
            'Governance in practice', LessonType.caseStudy, 40,
            LessonState.locked),
      ],
    ),
  ];

  static List<CourseModule> _governanceModules() => [
    CourseModule(
      id: 'mod-gov-1',
      courseId: 'course-governance',
      number: 1,
      title: 'The Board’s Role',
      lessons: [
        _lesson('les-gov-1', 'mod-gov-1', 'course-governance',
            'Duties of directors', LessonType.video, 20, LessonState.available),
        _lesson('les-gov-2', 'mod-gov-1', 'course-governance',
            'Board effectiveness', LessonType.text, 18, LessonState.locked),
      ],
    ),
  ];

  static List<CourseModule> _tradeModules() => [
    CourseModule(
      id: 'mod-trade-1',
      courseId: 'course-trade',
      number: 1,
      title: 'AfCFTA Foundations',
      lessons: [
        _lesson('les-trade-1', 'mod-trade-1', 'course-trade',
            'The continental market', LessonType.video, 25,
            LessonState.completed),
        _lesson('les-trade-2', 'mod-trade-1', 'course-trade',
            'Rules of origin', LessonType.pdf, 22, LessonState.completed),
      ],
    ),
  ];

  static Lesson _lesson(
    String id,
    String moduleId,
    String courseId,
    String title,
    LessonType type,
    int minutes,
    LessonState state,
  ) => Lesson(
    id: id,
    moduleId: moduleId,
    courseId: courseId,
    title: title,
    type: type,
    durationMinutes: minutes,
    state: state,
    description:
        'A focused session designed around decisions executives actually face.',
    objectives: const [
      'Understand the core framework',
      'Apply it to a live organisational question',
    ],
    resources: const [
      LessonResource(title: 'Session slides', kind: 'PDF'),
      LessonResource(title: 'Further reading', kind: 'Article'),
    ],
    body:
        'This session sets out the essential framework, then works through how '
        'it applies in an African executive context. Use the resources below '
        'alongside the material, and record your own notes as you go.',
  );

  List<Assessment> _seedAssessments() => [
    Assessment(
      id: 'ass-1',
      title: 'Strategic Management Assessment',
      courseId: 'course-leadership',
      courseTitle: 'Executive Leadership & Governance',
      programmeTitle: 'Executive Leadership & Governance',
      type: AssessmentType.executiveAssignment,
      status: AssessmentStatus.available,
      durationMinutes: 120,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      attemptsAllowed: 2,
    ),
    Assessment(
      id: 'ass-2',
      title: 'Capital Structure Quiz',
      courseId: 'course-finance',
      courseTitle: 'Corporate Finance for Executives',
      programmeTitle: 'Corporate Finance for Executives',
      type: AssessmentType.quiz,
      status: AssessmentStatus.upcoming,
      durationMinutes: 45,
      dueDate: DateTime.now().add(const Duration(days: 11)),
      attemptsAllowed: 3,
    ),
    Assessment(
      id: 'ass-3',
      title: 'Trade Strategy Capstone',
      courseId: 'course-trade',
      courseTitle: 'Africa Trade & Investment Strategy',
      programmeTitle: 'Africa Trade & Investment',
      type: AssessmentType.capstone,
      status: AssessmentStatus.completed,
      durationMinutes: 240,
      dueDate: DateTime.now().subtract(const Duration(days: 24)),
      attemptsAllowed: 1,
      attemptsUsed: 1,
    ),
  ];

  List<AssessmentResult> _seedResults() => [
    AssessmentResult(
      id: 'res-1',
      assessmentId: 'ass-3',
      assessmentTitle: 'Trade Strategy Capstone',
      courseTitle: 'Africa Trade & Investment Strategy',
      date: DateTime.now().subtract(const Duration(days: 18)),
      score: 82,
      maximumScore: 100,
      grade: 'Distinction',
      outcome: ResultOutcome.passed,
      markedBy: 'Prof. Selassie Bekele',
      feedback:
          'A well-argued strategy with strong use of the AfCFTA framework. '
          'Deepen the risk analysis in future submissions.',
    ),
    AssessmentResult(
      id: 'res-2',
      assessmentId: 'ass-4',
      assessmentTitle: 'Governance Foundations Quiz',
      courseTitle: 'Executive Leadership & Governance',
      date: DateTime.now().subtract(const Duration(days: 40)),
      score: 68,
      maximumScore: 100,
      grade: 'Merit',
      outcome: ResultOutcome.passed,
      markedBy: 'Dr. Amina Yusuf',
    ),
  ];

  List<Certificate> _seedCertificates() => [
    Certificate(
      id: 'cert-trade',
      title: 'Africa Trade & Investment Executive Certificate',
      programmeTitle: 'Africa Trade & Investment',
      status: CertificateStatus.issued,
      certificateNumber: 'WEA-ATI-2026-0148',
      issuedOn: DateTime.now().subtract(const Duration(days: 12)),
    ),
    const Certificate(
      id: 'cert-finance',
      title: 'Corporate Finance for Executives',
      programmeTitle: 'Corporate Finance for Executives',
      status: CertificateStatus.pending,
      certificateNumber: '—',
    ),
  ];

  List<Credential> _seedCredentials() => [
    Credential(
      id: 'cred-1',
      title: 'Africa Trade & Investment — Verified Credential',
      issuer: 'WUCO Executive Academy',
      credentialId: 'WEA-CRED-8842-ATI',
      status: CredentialStatus.active,
      issuedOn: DateTime.now().subtract(const Duration(days: 12)),
      skills: const ['AfCFTA', 'Cross-border trade', 'Investment strategy'],
    ),
  ];

  CpdSummary _seedCpd() => CpdSummary(
    year: DateTime.now().year,
    pointsEarned: 42,
    pointsTarget: 60,
    records: [
      CpdRecord(
        id: 'cpd-1',
        title: 'Africa Trade & Investment Strategy',
        source: 'Programme completion',
        points: 30,
        awardedOn: DateTime.now().subtract(const Duration(days: 12)),
      ),
      CpdRecord(
        id: 'cpd-2',
        title: 'Executive Leadership — Modules 1–2',
        source: 'Course progress',
        points: 8,
        awardedOn: DateTime.now().subtract(const Duration(days: 30)),
      ),
      CpdRecord(
        id: 'cpd-3',
        title: 'Governance Foundations Quiz',
        source: 'Assessment',
        points: 4,
        awardedOn: DateTime.now().subtract(const Duration(days: 40)),
      ),
    ],
  );

  List<LearnerNotification> _seedNotifications() => [
    LearnerNotification(
      id: 'note-1',
      title: 'Your certificate is ready',
      message:
          'The Africa Trade & Investment Executive Certificate has been issued.',
      category: NotificationCategory.certificate,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      actionRoute: '/learner/certificates',
    ),
    LearnerNotification(
      id: 'note-2',
      title: 'Assessment due in 3 days',
      message: 'Strategic Management Assessment closes on Friday.',
      category: NotificationCategory.assessment,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      actionRoute: '/learner/assessments',
    ),
    LearnerNotification(
      id: 'note-3',
      title: 'Results published',
      message: 'Your Trade Strategy Capstone result is available.',
      category: NotificationCategory.result,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      read: true,
      actionRoute: '/learner/results',
    ),
    LearnerNotification(
      id: 'note-4',
      title: 'New module unlocked',
      message: 'Capital Structure & Valuation is now available.',
      category: NotificationCategory.course,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      read: true,
      actionRoute: '/learner/courses/course-finance',
    ),
  ];

  List<LearningActivity> _seedActivity() => [
    LearningActivity(
      id: 'act-1',
      type: ActivityType.lessonCompleted,
      title: 'Net present value',
      detail: 'Corporate Finance for Executives',
      occurredAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    LearningActivity(
      id: 'act-2',
      type: ActivityType.certificateEarned,
      title: 'Africa Trade & Investment Executive Certificate',
      detail: 'Issued by WUCO Executive Academy',
      occurredAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
    LearningActivity(
      id: 'act-3',
      type: ActivityType.assessmentSubmitted,
      title: 'Trade Strategy Capstone',
      detail: 'Africa Trade & Investment Strategy',
      occurredAt: DateTime.now().subtract(const Duration(days: 24)),
    ),
    LearningActivity(
      id: 'act-4',
      type: ActivityType.cpdUpdated,
      title: '30 CPD points awarded',
      detail: 'Programme completion',
      occurredAt: DateTime.now().subtract(const Duration(days: 12)),
    ),
  ];

  List<LessonNote> _seedNotes() => [
    LessonNote(
      id: 'note-seed-1',
      courseId: 'course-finance',
      lessonId: 'les-fin-4',
      body:
          'NPV assumes we can actually finance at the discount rate — check '
          'this against our current facility before the board paper.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  List<UpcomingActivity> _seedUpcoming() => [
    UpcomingActivity(
      id: 'up-1',
      kind: UpcomingKind.liveClass,
      title: 'Executive Leadership Seminar',
      context: 'Live session · Dr. Amina Yusuf',
      dueAt: DateTime.now().add(const Duration(days: 1)),
    ),
    UpcomingActivity(
      id: 'up-2',
      kind: UpcomingKind.assessment,
      title: 'Strategic Management Assessment',
      context: 'Executive Leadership & Governance',
      dueAt: DateTime.now().add(const Duration(days: 3)),
      actionRoute: '/learner/assessments',
    ),
    UpcomingActivity(
      id: 'up-3',
      kind: UpcomingKind.milestone,
      title: 'Module 3 begins',
      context: 'Corporate Finance for Executives',
      dueAt: DateTime.now().add(const Duration(days: 8)),
    ),
  ];
}
