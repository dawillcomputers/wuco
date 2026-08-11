import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_environment.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/api_catalogue_repository.dart';
import '../data/catalogue_repository.dart';
import '../data/mock_catalogue_repository.dart';
import '../domain/catalogue_models.dart';
import '../domain/registration_models.dart';

/// The live catalogue when an API is configured, otherwise the offline slice.
final catalogueRepositoryProvider = Provider<CatalogueRepository>((ref) {
  if (AppEnvironmentConfig.hasApiConfiguration) {
    return ApiCatalogueRepository(
      baseUrl: AppEnvironmentConfig.apiBaseUrl,
      sessionStore: ref.watch(sessionStoreProvider),
    );
  }
  return MockCatalogueRepository();
});

/// Content administration. Null when no API is configured, because there is
/// nothing to administer offline — the CMS shows an explanation instead.
final catalogueAdminRepositoryProvider = Provider<CatalogueAdminRepository?>((
  ref,
) {
  if (!AppEnvironmentConfig.hasApiConfiguration) return null;
  return ApiCatalogueRepository(
    baseUrl: AppEnvironmentConfig.apiBaseUrl,
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

// --- Public reads -----------------------------------------------------------

final catalogueOverviewProvider = FutureProvider<CatalogueOverview>(
  (ref) => ref.watch(catalogueRepositoryProvider).overview(),
);

final areaDetailProvider = FutureProvider.family<AreaDetail, String>(
  (ref, slug) => ref.watch(catalogueRepositoryProvider).area(slug),
);

final programmeDetailProvider = FutureProvider.family<ProgrammeDetail, String>(
  (ref, slug) => ref.watch(catalogueRepositoryProvider).programme(slug),
);

/// Featured programmes for the homepage.
final featuredProgrammesProvider = FutureProvider<List<CatalogueProgramme>>(
  (ref) => ref
      .watch(catalogueRepositoryProvider)
      .programmes(featuredOnly: true, limit: 6),
);

final publicFacultyProvider = FutureProvider<List<FacultyProfile>>(
  (ref) => ref.watch(catalogueRepositoryProvider).faculty(),
);

final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>(
  (ref) => ref.watch(catalogueRepositoryProvider).paymentMethods(),
);

/// Filter state for the public programme browser.
class CatalogueFilter {
  const CatalogueFilter({this.area = '', this.type = '', this.query = ''});

  final String area;
  final String type;
  final String query;

  CatalogueFilter copyWith({String? area, String? type, String? query}) =>
      CatalogueFilter(
        area: area ?? this.area,
        type: type ?? this.type,
        query: query ?? this.query,
      );

  bool get isEmpty => area.isEmpty && type.isEmpty && query.trim().isEmpty;
}

class CatalogueFilterNotifier extends Notifier<CatalogueFilter> {
  @override
  CatalogueFilter build() => const CatalogueFilter();

  void setArea(String area) => state = state.copyWith(area: area);
  void setType(String type) => state = state.copyWith(type: type);
  void setQuery(String query) => state = state.copyWith(query: query);
  void clear() => state = const CatalogueFilter();
}

final catalogueFilterProvider =
    NotifierProvider<CatalogueFilterNotifier, CatalogueFilter>(
      CatalogueFilterNotifier.new,
    );

final filteredCatalogueProvider = FutureProvider<List<CatalogueProgramme>>((
  ref,
) {
  final filter = ref.watch(catalogueFilterProvider);
  return ref
      .watch(catalogueRepositoryProvider)
      .programmes(area: filter.area, type: filter.type, query: filter.query);
});

// --- Registration -----------------------------------------------------------

final registrationContextProvider =
    FutureProvider.family<RegistrationContext, String>(
      (ref, programmeId) => ref
          .watch(catalogueRepositoryProvider)
          .registrationContext(programmeId),
    );

final myRegistrationsProvider = FutureProvider<List<RegistrationRecord>>(
  (ref) => ref.watch(catalogueRepositoryProvider).myRegistrations(),
);

/// Actions that change catalogue-related state, kept out of widgets.
class CatalogueActions {
  const CatalogueActions(this._ref);
  final Ref _ref;

  Future<RegistrationRecord> register({
    required String programmeId,
    required Map<String, String> answers,
    String? paymentMethodId,
  }) async {
    final record = await _ref
        .read(catalogueRepositoryProvider)
        .register(
          programmeId: programmeId,
          answers: answers,
          paymentMethodId: paymentMethodId,
        );
    _ref
      ..invalidate(myRegistrationsProvider)
      ..invalidate(registrationContextProvider(programmeId));
    return record;
  }

  /// Called after any content change so the public site reflects it without a
  /// reload.
  void refreshCatalogue() {
    _ref
      ..invalidate(catalogueOverviewProvider)
      ..invalidate(featuredProgrammesProvider)
      ..invalidate(filteredCatalogueProvider)
      ..invalidate(areaDetailProvider)
      ..invalidate(programmeDetailProvider)
      ..invalidate(publicFacultyProvider)
      ..invalidate(paymentMethodsProvider);
  }
}

final catalogueActionsProvider = Provider<CatalogueActions>(
  (ref) => CatalogueActions(ref),
);
