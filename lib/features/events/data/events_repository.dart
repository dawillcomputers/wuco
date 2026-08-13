import '../domain/event_models.dart';

/// Why an event call failed, in terms the interface can act on.
enum EventFailureKind {
  network,
  notFound,
  notAuthorised,
  accountRequired,
  registrationClosed,
  eventFull,
  missingAnswer,
  invalidEmail,
  alreadyPaid,
  paymentRequired,
  paymentFailed,
  sessionNotLive,
  invalidRequest,
  server,
}

class EventFailure implements Exception {
  const EventFailure(this.kind, [this.detail]);

  final EventFailureKind kind;
  final String? detail;

  /// Wording shown to a visitor. Never a backend message verbatim.
  String get message => switch (kind) {
    EventFailureKind.network =>
      'Unable to connect. Please check your internet connection and try again.',
    EventFailureKind.notFound => 'That event is no longer available.',
    EventFailureKind.notAuthorised =>
      'You do not have permission to view that registration.',
    EventFailureKind.accountRequired =>
      'This event is open to WEA account holders. Please sign in to register.',
    EventFailureKind.registrationClosed =>
      'Registration for this event is closed.',
    EventFailureKind.eventFull => 'This event has reached capacity.',
    EventFailureKind.missingAnswer =>
      'Please provide ${detail ?? 'every required detail'} before continuing.',
    EventFailureKind.invalidEmail => 'Please enter a valid email address.',
    EventFailureKind.alreadyPaid =>
      'This registration has already been paid for.',
    EventFailureKind.paymentRequired =>
      'Your payment has not been completed, so this is not yet available.',
    EventFailureKind.paymentFailed =>
      'The payment could not be started. Please try again shortly.',
    EventFailureKind.sessionNotLive =>
      'This session has not opened yet. Please try again when it begins.',
    EventFailureKind.invalidRequest =>
      'Some of the details supplied were not accepted. Please review and try again.',
    EventFailureKind.server =>
      'Something went wrong at our end. Please try again shortly.',
  };
}

/// What the registrant has filled in so far.
///
/// Sent at every step, not only at the end: partial information is saved so an
/// abandoned registration is still a person the academy can follow up.
class EventRegistrationDraft {
  const EventRegistrationDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone = '',
    this.organisation = '',
    this.jobTitle = '',
    this.country = '',
    this.answers = const {},
    this.complete = false,
    this.source = '',
    this.campaign = const {},
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String organisation;
  final String jobTitle;
  final String country;
  final Map<String, String> answers;

  /// True only on the final save, when required questions are enforced.
  final bool complete;
  final String source;

  /// utm_source / utm_medium / utm_campaign from the link they arrived on.
  final Map<String, String> campaign;

  Map<String, dynamic> toMap() => {
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'phone': phone,
    'organisation': organisation,
    'job_title': jobTitle,
    'country': country,
    'answers': answers,
    'stage': complete ? 'COMPLETE' : 'PARTIAL',
    'source': source,
    'utm_source': campaign['utm_source'] ?? '',
    'utm_medium': campaign['utm_medium'] ?? '',
    'utm_campaign': campaign['utm_campaign'] ?? '',
  };
}

/// A saved registration, with the token a guest needs to return to it.
class SavedRegistration {
  const SavedRegistration({
    required this.registration,
    this.resumeToken,
    this.temporaryPassword,
  });

  final EventRegistration registration;

  /// Issued once, when completing the registration created a WEA account for
  /// somebody who did not have one. Shown to them and emailed, and it stops
  /// working as soon as they choose their own.
  final String? temporaryPassword;

  /// Issued once, when a guest registration is created. Held by the client so
  /// the registrant can come back to their own registration without an account.
  final String? resumeToken;
}

/// The public event experience: browsing, registering, paying, participating.
abstract interface class EventsRepository {
  Future<List<WeaEvent>> events({bool upcomingOnly, bool featuredOnly, String? query});

  Future<EventDetail> event(String slug);

  /// What the form should ask this person, and what it already knows.
  Future<EventRegistrationContext> registrationContext(String slug);

  /// Creates or updates the registration. Safe to call at every step.
  Future<SavedRegistration> saveRegistration(
    String slug,
    EventRegistrationDraft draft,
  );

  /// Starts a payment and returns either a checkout to open or instructions.
  Future<EventPaymentIntent> beginPayment(String reference);

  /// Asks the API to confirm with the processor what actually happened.
  Future<EventPaymentOutcome> verifyPayment(
    String reference, {
    String? paymentReference,
  });

  Future<EventDashboard> dashboard(String reference);

  /// Requests a live session link. Refused unless the registration entitles it.
  Future<String> joinSession(String reference, String sessionId);

  /// Every event the signed-in account has registered for.
  Future<List<MyEventRegistration>> myRegistrations();
}

/// Event administration. Super Admin only; the API re-checks every call.
abstract interface class EventsAdminRepository {
  Future<List<EventRegistrant>> registrants({
    String? eventId,
    String? status,
    String? paymentStatus,
    String? query,
  });

  Future<(EventOverview, EventFunnel)> overview({String? eventId});

  /// Chiefly for confirming a payment that arrived by bank transfer.
  Future<void> setRegistrationStatus(
    String registrationId, {
    required EventRegistrationStatus status,
    String note = '',
  });

  /// Moves stale attempts into the abandoned list. Nothing is deleted.
  Future<int> sweepAbandoned();

  /// Registrations as CSV, ready to save.
  Future<String> exportRegistrations({String? eventId});
}

/// Page visitation and campaign reporting.
abstract interface class SiteAnalyticsRepository {
  /// Records a page view. Failures are swallowed: analytics must never break
  /// the page it is measuring.
  Future<void> recordPageView({
    required String path,
    String title,
    String? eventId,
    Map<String, String> campaign = const {},
  });

  Future<void> recordFunnelEvent({
    required String name,
    String path,
    String? eventId,
    String? registrationId,
    Map<String, String> campaign = const {},
  });

  Future<Map<String, dynamic>> siteAnalytics({int days});

  Future<Map<String, dynamic>> shareLinks();
}
