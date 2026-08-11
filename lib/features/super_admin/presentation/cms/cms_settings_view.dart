import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../catalogue/data/catalogue_repository.dart';
import '../../application/cms_providers.dart';

/// Editable copy that appears on the public site.
///
/// Stored as key/value rows, so wording can be changed without a release. New
/// keys added by the backend appear here automatically.
class CmsSettingsView extends ConsumerStatefulWidget {
  const CmsSettingsView({super.key});

  @override
  ConsumerState<CmsSettingsView> createState() => _CmsSettingsViewState();
}

class _CmsSettingsViewState extends ConsumerState<CmsSettingsView> {
  final _controllers = <String, TextEditingController>{};
  var _saving = false;
  String? _message;

  static const _labels = {
    'catalogue_headline': 'Catalogue headline',
    'catalogue_intro': 'Catalogue introduction',
    'registration_intro': 'Registration introduction',
    'registration_reference_prefix': 'Registration reference prefix',
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(cmsActionsProvider).saveSettings({
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = 'Saved. The public site now shows the updated wording.';
      });
    } on CatalogueFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cmsSettingsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Website copy', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Wording shown on the public catalogue and registration pages.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: WEAInsets.lg),
        settings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(
            error is CatalogueFailure
                ? error.message
                : 'We could not load the site settings.',
          ),
          data: (values) {
            for (final entry in values.entries) {
              _controllers.putIfAbsent(
                entry.key,
                () => TextEditingController(text: entry.value),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final key in _controllers.keys) ...[
                  TextField(
                    controller: _controllers[key],
                    maxLines: key.contains('intro') ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: _labels[key] ?? key,
                      helperText: _labels.containsKey(key) ? null : key,
                    ),
                  ),
                  const SizedBox(height: WEAInsets.md),
                ],
                if (_message != null) ...[
                  Text(_message!, style: theme.textTheme.bodySmall),
                  const SizedBox(height: WEAInsets.sm),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'SAVING…' : 'SAVE CHANGES'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: WEAInsets.xl),
        Container(
          padding: const EdgeInsets.all(WEAInsets.md),
          decoration: BoxDecoration(
            color: WEAColors.surfaceMuted,
            borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: WEAColors.mutedText,
              ),
              const SizedBox(width: WEAInsets.sm),
              Expanded(
                child: Text(
                  'Programme content, pricing, faculty, schedules and payment '
                  'details are managed under Catalogue. Nothing on the public '
                  'site is fixed in code.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
