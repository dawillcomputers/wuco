import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalogue/application/catalogue_providers.dart';
import '../../catalogue/data/catalogue_repository.dart';
import '../../catalogue/domain/registration_models.dart';

/// A resource listing, optionally scoped to a parent row.
typedef CmsQuery = ({String resource, String? filterColumn, String? filterValue});

/// Rows for one CMS resource. Watching this keeps the list live after edits.
final cmsListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, CmsQuery>((
      ref,
      query,
    ) async {
      final admin = ref.watch(catalogueAdminRepositoryProvider);
      if (admin == null) return const [];
      return admin.list(
        query.resource,
        filters: query.filterColumn == null || query.filterValue == null
            ? null
            : {query.filterColumn!: query.filterValue!},
      );
    });

/// Rows used to populate a reference dropdown.
final cmsOptionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      resource,
    ) async {
      final admin = ref.watch(catalogueAdminRepositoryProvider);
      if (admin == null) return const [];
      return admin.list(resource);
    });

final cmsRegistrationsProvider =
    FutureProvider.family<List<RegistrationRecord>, String?>((
      ref,
      status,
    ) async {
      final admin = ref.watch(catalogueAdminRepositoryProvider);
      if (admin == null) return const [];
      return admin.registrations(status: status);
    });

final cmsSettingsProvider = FutureProvider<Map<String, String>>((ref) async {
  final admin = ref.watch(catalogueAdminRepositoryProvider);
  if (admin == null) return const {};
  return admin.settings();
});

/// Writes, kept out of widgets. Every method refreshes the affected lists and
/// the public catalogue, so a change is visible on the site immediately.
class CmsActions {
  const CmsActions(this._ref);
  final Ref _ref;

  CatalogueAdminRepository get _admin {
    final admin = _ref.read(catalogueAdminRepositoryProvider);
    if (admin == null) {
      throw const CatalogueFailure(
        CatalogueFailureKind.notAuthorised,
        'Content management needs a connected API.',
      );
    }
    return admin;
  }

  void _refresh() {
    _ref.invalidate(cmsListProvider);
    _ref.invalidate(cmsOptionsProvider);
    _ref.read(catalogueActionsProvider).refreshCatalogue();
  }

  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  ) async {
    final row = await _admin.create(resource, values);
    _refresh();
    return row;
  }

  Future<Map<String, dynamic>> update(
    String resource,
    String id,
    Map<String, dynamic> values,
  ) async {
    final row = await _admin.update(resource, id, values);
    _refresh();
    return row;
  }

  Future<void> delete(String resource, String id) async {
    await _admin.delete(resource, id);
    _refresh();
  }

  /// Publish, unpublish or archive without opening the full editor.
  Future<void> setStatus(String resource, String id, String status) =>
      update(resource, id, {'status': status});

  Future<void> reorder(String resource, List<String> ids) async {
    await _admin.reorder(resource, ids);
    _refresh();
  }

  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) => _admin.uploadImage(
    bytes: bytes,
    filename: filename,
    contentType: contentType,
  );

  Future<void> reviewRegistration(
    String id, {
    required RegistrationStatus status,
    String note = '',
  }) async {
    await _admin.reviewRegistration(id, status: status, note: note);
    _ref.invalidate(cmsRegistrationsProvider);
  }

  Future<void> saveSettings(Map<String, String> values) async {
    await _admin.saveSettings(values);
    _ref.invalidate(cmsSettingsProvider);
    _ref.read(catalogueActionsProvider).refreshCatalogue();
  }
}

final cmsActionsProvider = Provider<CmsActions>((ref) => CmsActions(ref));
