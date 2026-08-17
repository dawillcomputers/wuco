import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_environment.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/api_events_repository.dart';
import '../data/events_repository.dart';
import '../data/offline_events_repository.dart';
import '../data/registration_token_store.dart';
import '../domain/event_models.dart';

/// Tokens that let a guest return to their own registration.
final registrationTokenStoreProvider = Provider<RegistrationTokenStore>(
  (ref) => RegistrationTokenStore(),
);

final _offlineEvents = OfflineEventsRepository();

ApiEventsRepository _apiClient(Ref ref) => ApiEventsRepository(
  baseUrl: AppEnvironmentConfig.apiBaseUrl,
  sessionStore: ref.watch(sessionStoreProvider),
  tokenStore: ref.watch(registrationTokenStoreProvider),
);

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => AppEnvironmentConfig.hasApiConfiguration
      ? _apiClient(ref)
      : _offlineEvents,
);

final eventsAdminRepositoryProvider = Provider<EventsAdminRepository>(
  (ref) => AppEnvironmentConfig.hasApiConfiguration
      ? _apiClient(ref)
      : _offlineEvents,
);

final siteAnalyticsRepositoryProvider = Provider<SiteAnalyticsRepository>(
  (ref) => AppEnvironmentConfig.hasApiConfiguration
      ? _apiClient(ref)
      : _offlineEvents,
);

/// Campaign parameters from the link the visitor arrived on.
///
/// Read once, from the launch URL, so a registration can be attributed to the
/// LinkedIn post or newsletter that produced it. Nothing here identifies a
/// person — it names a campaign.
final campaignProvider = Provider<Map<String, String>>((ref) {
  final params = Uri.base.queryParameters;
  return {
    for (final key in const ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content'])
      if ((params[key] ?? '').trim().isNotEmpty) key: params[key]!.trim(),
    if ((params['wea_ref'] ?? '').trim().isNotEmpty)
      'share_code': params['wea_ref']!.trim(),
  };
});

// --- Public reads ------------------------------------------------------------

typedef EventQuery = ({bool upcomingOnly, bool featuredOnly, String? search});

const upcomingEvents = (upcomingOnly: true, featuredOnly: false, search: null);

final eventsListProvider = FutureProvider.family<List<WeaEvent>, EventQuery>(
  (ref, query) => ref
      .watch(eventsRepositoryProvider)
      .events(
        upcomingOnly: query.upcomingOnly,
        featuredOnly: query.featuredOnly,
        query: query.search,
      ),
);

final eventDetailProvider = FutureProvider.family<EventDetail, String>(
  (ref, slug) => ref.watch(eventsRepositoryProvider).event(slug),
);

final eventRegistrationContextProvider =
    FutureProvider.family<EventRegistrationContext, String>(
      (ref, slug) => ref.watch(eventsRepositoryProvider).registrationContext(slug),
    );

final eventDashboardProvider = FutureProvider.family<EventDashboard, String>(
  (ref, reference) => ref.watch(eventsRepositoryProvider).dashboard(reference),
);

/// The methods, prices and rate this event can take, as the server reports them.
typedef PaymentQuery = ({String slug, String? attendanceMode});

final eventPaymentMethodsProvider =
    FutureProvider.family<EventPaymentOptions, PaymentQuery>(
      (ref, query) => ref
          .watch(eventsRepositoryProvider)
          .paymentMethods(query.slug, attendanceMode: query.attendanceMode),
    );

/// Every event the signed-in account has registered for. Empty when signed out.
final myEventRegistrationsProvider =
    FutureProvider<List<MyEventRegistration>>((ref) {
      final signedIn = ref.watch(authControllerProvider).isAuthenticated;
      if (!signedIn) return Future.value(const []);
      return ref.watch(eventsRepositoryProvider).myRegistrations();
    });

// --- Administration ----------------------------------------------------------

typedef RegistrantQuery = ({
  String? eventId,
  String? status,
  String? paymentStatus,
  String? search,
});

final adminRegistrantsProvider =
    FutureProvider.family<List<EventRegistrant>, RegistrantQuery>(
      (ref, query) => ref
          .watch(eventsAdminRepositoryProvider)
          .registrants(
            eventId: query.eventId,
            status: query.status,
            paymentStatus: query.paymentStatus,
            query: query.search,
          ),
    );

final adminEventOverviewProvider =
    FutureProvider.family<(EventOverview, EventFunnel), String?>(
      (ref, eventId) =>
          ref.watch(eventsAdminRepositoryProvider).overview(eventId: eventId),
    );

final siteAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, days) => ref.watch(siteAnalyticsRepositoryProvider).siteAnalytics(days: days),
);

final shareLinksProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(siteAnalyticsRepositoryProvider).shareLinks(),
);

// --- Writes ------------------------------------------------------------------

/// Everything that changes state, kept out of widgets.
class EventActions {
  const EventActions(this._ref);
  final Ref _ref;

  EventsRepository get _events => _ref.read(eventsRepositoryProvider);
  EventsAdminRepository get _admin => _ref.read(eventsAdminRepositoryProvider);
  SiteAnalyticsRepository get _analytics =>
      _ref.read(siteAnalyticsRepositoryProvider);

  /// Saves whatever the registrant has given so far.
  ///
  /// Called at every step rather than only at the end, so somebody who stops
  /// halfway is still a registration the academy holds.
  Future<SavedRegistration> save(
    String slug,
    EventRegistrationDraft draft,
  ) async {
    final campaign = _ref.read(campaignProvider);
    final saved = await _events.saveRegistration(
      slug,
      EventRegistrationDraft(
        firstName: draft.firstName,
        lastName: draft.lastName,
        email: draft.email,
        phone: draft.phone,
        organisation: draft.organisation,
        jobTitle: draft.jobTitle,
        country: draft.country,
        answers: draft.answers,
        complete: draft.complete,
        source: draft.source,
        campaign: campaign,
      ),
    );
    unawaitedReport(
      name: draft.complete
          ? 'registration_form_completed'
          : 'registration_information_submitted',
      eventId: saved.registration.eventId,
      registrationId: saved.registration.id,
    );
    // Completing a registration can create the account and sign them in. The
    // controller is told so the header, the guards and every other reader
    // agree that somebody is now signed in.
    if (saved.signedIn) {
      await _ref.read(authControllerProvider.notifier).restore();
    }
    _ref.invalidate(eventRegistrationContextProvider(slug));
    _ref.invalidate(myEventRegistrationsProvider);
    return saved;
  }

  Future<EventPaymentIntent> beginPayment(
    String reference, {
    String? methodKey,
    String? attendanceMode,
  }) async {
    final intent = await _events.beginPayment(
      reference,
      methodKey: methodKey,
      attendanceMode: attendanceMode,
    );
    unawaitedReport(name: 'payment_started');
    return intent;
  }

  Future<EventPaymentOutcome> verifyPayment(
    String reference, {
    String? paymentReference,
  }) async {
    final outcome = await _events.verifyPayment(
      reference,
      paymentReference: paymentReference,
    );
    unawaitedReport(
      name: outcome.succeeded
          ? 'payment_success'
          : outcome.pending
          ? 'payment_pending'
          : 'payment_failed',
    );
    _ref.invalidate(eventDashboardProvider(reference));
    _ref.invalidate(myEventRegistrationsProvider);
    return outcome;
  }

  Future<String> joinSession(String reference, String sessionId) =>
      _events.joinSession(reference, sessionId);

  Future<void> setRegistrationStatus(
    String registrationId, {
    required EventRegistrationStatus status,
    String note = '',
  }) async {
    await _admin.setRegistrationStatus(
      registrationId,
      status: status,
      note: note,
    );
    _ref.invalidate(adminRegistrantsProvider);
    _ref.invalidate(adminEventOverviewProvider);
  }

  Future<int> sweepAbandoned() async {
    final updated = await _admin.sweepAbandoned();
    _ref.invalidate(adminRegistrantsProvider);
    _ref.invalidate(adminEventOverviewProvider);
    return updated;
  }

  Future<String> exportRegistrations({String? eventId}) =>
      _admin.exportRegistrations(eventId: eventId);

  /// Fire-and-forget progress reporting. Never awaited by the interface.
  void unawaitedReport({
    required String name,
    String path = '',
    String? eventId,
    String? registrationId,
  }) {
    _analytics.recordFunnelEvent(
      name: name,
      path: path,
      eventId: eventId,
      registrationId: registrationId,
      campaign: _ref.read(campaignProvider),
    );
  }

  void recordPageView(String path, {String title = '', String? eventId}) {
    _analytics.recordPageView(
      path: path,
      title: title,
      eventId: eventId,
      campaign: _ref.read(campaignProvider),
    );
  }
}

final eventActionsProvider = Provider<EventActions>((ref) => EventActions(ref));
