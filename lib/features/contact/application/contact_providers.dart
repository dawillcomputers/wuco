import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_environment.dart';
import '../../authentication/application/auth_controller.dart';
import '../../catalogue/data/api_catalogue_repository.dart';
import '../data/contact_repository.dart';
import '../domain/contact_models.dart';

/// In-memory stand-in used when no API is configured, so the contact form is
/// still exercisable offline. Nothing is delivered anywhere.
class _OfflineContactRepository
    implements ContactRepository, ContactAdminRepository {
  final _messages = <Enquiry>[];

  @override
  Future<String> sendEnquiry(EnquiryDraft draft) async {
    final reference = 'WEA-ENQ-${(_messages.length + 1).toString().padLeft(5, '0')}';
    _messages.insert(
      0,
      Enquiry(
        id: 'enq-${_messages.length + 1}',
        reference: reference,
        name: draft.name,
        email: draft.email,
        subject: draft.subject,
        message: draft.message,
        status: EnquiryStatus.isNew,
        replies: const [],
        phone: draft.phone,
        organisation: draft.organisation,
        createdAt: DateTime.now(),
      ),
    );
    return reference;
  }

  @override
  Future<List<Enquiry>> myEnquiries() async => List.unmodifiable(_messages);

  @override
  Future<void> followUp({required String enquiryId, required String body}) async {}

  @override
  Future<List<Enquiry>> enquiries({EnquiryStatus? status}) async => [
    for (final message in _messages)
      if (status == null || message.status == status) message,
  ];

  @override
  Future<void> reply({required String enquiryId, required String body}) async {}

  @override
  Future<void> setStatus({
    required String enquiryId,
    required EnquiryStatus status,
  }) async {}
}

final _offlineContact = _OfflineContactRepository();

ApiCatalogueRepository _apiClient(Ref ref) => ApiCatalogueRepository(
  baseUrl: AppEnvironmentConfig.apiBaseUrl,
  sessionStore: ref.watch(sessionStoreProvider),
);

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => AppEnvironmentConfig.hasApiConfiguration
      ? _apiClient(ref)
      : _offlineContact,
);

final contactAdminRepositoryProvider = Provider<ContactAdminRepository>(
  (ref) => AppEnvironmentConfig.hasApiConfiguration
      ? _apiClient(ref)
      : _offlineContact,
);

/// The signed-in sender's own enquiry threads. Empty when signed out.
final myEnquiriesProvider = FutureProvider<List<Enquiry>>((ref) {
  final signedIn = ref.watch(authControllerProvider).isAuthenticated;
  if (!signedIn) return Future.value(const []);
  return ref.watch(contactRepositoryProvider).myEnquiries();
});

final adminEnquiriesProvider =
    FutureProvider.family<List<Enquiry>, EnquiryStatus?>(
      (ref, status) =>
          ref.watch(contactAdminRepositoryProvider).enquiries(status: status),
    );

/// Writes, kept out of widgets.
class ContactActions {
  const ContactActions(this._ref);
  final Ref _ref;

  Future<String> send(EnquiryDraft draft) async {
    final reference = await _ref.read(contactRepositoryProvider).sendEnquiry(draft);
    _ref.invalidate(myEnquiriesProvider);
    return reference;
  }

  Future<void> followUp({required String enquiryId, required String body}) async {
    await _ref
        .read(contactRepositoryProvider)
        .followUp(enquiryId: enquiryId, body: body);
    _ref.invalidate(myEnquiriesProvider);
  }

  Future<void> reply({required String enquiryId, required String body}) async {
    await _ref
        .read(contactAdminRepositoryProvider)
        .reply(enquiryId: enquiryId, body: body);
    _ref.invalidate(adminEnquiriesProvider);
  }

  Future<void> setStatus({
    required String enquiryId,
    required EnquiryStatus status,
  }) async {
    await _ref
        .read(contactAdminRepositoryProvider)
        .setStatus(enquiryId: enquiryId, status: status);
    _ref.invalidate(adminEnquiriesProvider);
  }
}

final contactActionsProvider = Provider<ContactActions>(
  (ref) => ContactActions(ref),
);
