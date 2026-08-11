import '../domain/catalogue_models.dart';
import '../domain/registration_models.dart';

/// Why a catalogue call failed, in terms the interface can act on.
enum CatalogueFailureKind {
  network,
  notFound,
  notAuthorised,
  alreadyRegistered,
  registrationClosed,
  missingAnswer,
  invalidRequest,
  server,
}

class CatalogueFailure implements Exception {
  const CatalogueFailure(this.kind, [this.detail]);

  final CatalogueFailureKind kind;
  final String? detail;

  /// Wording shown to a visitor. Never exposes a backend message verbatim.
  String get message => switch (kind) {
    CatalogueFailureKind.network =>
      'Unable to connect. Please check your internet connection and try again.',
    CatalogueFailureKind.notFound =>
      'That programme is no longer available.',
    CatalogueFailureKind.notAuthorised =>
      'You do not have permission to do that.',
    CatalogueFailureKind.alreadyRegistered =>
      'You have already registered for this programme.',
    CatalogueFailureKind.registrationClosed =>
      'Registration for this programme is currently closed.',
    CatalogueFailureKind.missingAnswer =>
      'Please answer ${detail ?? 'every required question'} before submitting.',
    CatalogueFailureKind.invalidRequest =>
      'Some of the details supplied were not accepted. Please review and try again.',
    CatalogueFailureKind.server =>
      'Something went wrong at our end. Please try again shortly.',
  };
}

/// Everything the public site and registration flow read.
///
/// The catalogue is content, not code: no programme, area or type is compiled
/// into the application, so publishing one is a database change made by a
/// Super Admin.
abstract interface class CatalogueRepository {
  Future<CatalogueOverview> overview();
  Future<AreaDetail> area(String slug);
  Future<List<CatalogueProgramme>> programmes({
    String? area,
    String? type,
    String? query,
    bool featuredOnly,
    int? limit,
  });
  Future<ProgrammeDetail> programme(String slug);
  Future<List<FacultyProfile>> faculty();
  Future<List<PaymentMethod>> paymentMethods();

  /// What still needs asking of this applicant for this programme.
  Future<RegistrationContext> registrationContext(String programmeId);

  Future<RegistrationRecord> register({
    required String programmeId,
    required Map<String, String> answers,
    String? paymentMethodId,
  });

  Future<List<RegistrationRecord>> myRegistrations();
}

/// Content administration. Every method requires a Super Admin session; the
/// Worker re-checks the role on each call.
abstract interface class CatalogueAdminRepository {
  Future<List<Map<String, dynamic>>> list(
    String resource, {
    Map<String, String>? filters,
  });

  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  );

  Future<Map<String, dynamic>> update(
    String resource,
    String id,
    Map<String, dynamic> values,
  );

  Future<void> delete(String resource, String id);

  Future<void> reorder(String resource, List<String> ids);

  /// Uploads an image and returns the stored asset key.
  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });

  Future<List<Map<String, dynamic>>> mediaLibrary();

  Future<void> setProgrammeFaculty(String programmeId, List<String> facultyIds);

  Future<List<RegistrationRecord>> registrations({String? status});

  Future<void> reviewRegistration(
    String registrationId, {
    required RegistrationStatus status,
    String note,
  });

  Future<Map<String, String>> settings();
  Future<void> saveSettings(Map<String, String> values);
}
