import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/app_environment.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../../../shared/components/wea_components.dart';
import 'cms_registrations_view.dart';
import 'cms_resource_view.dart';
import 'cms_schema.dart';
import 'cms_settings_view.dart';

/// Content management for the whole academy.
///
/// Every catalogue entity is managed here, so publishing a programme, changing
/// its artwork or adding a new programme type never requires a release.
class CmsScreen extends ConsumerStatefulWidget {
  const CmsScreen({super.key});

  @override
  ConsumerState<CmsScreen> createState() => _CmsScreenState();
}

class _CmsScreenState extends ConsumerState<CmsScreen> {
  /// Resource name, or one of the pseudo-sections below.
  String _section = cmsResources.first.name;

  static const _registrations = '__registrations__';
  static const _settings = '__settings__';

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Scaffold(
      backgroundColor: WEAColors.secondaryBackground,
      appBar: AppBar(
        backgroundColor: WEAColors.navy,
        foregroundColor: WEAColors.offWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        title: const WEABrandLockup(height: 46, onDark: true),
        actions: [
          TextButton(
            onPressed: () => context.go('/programmes'),
            style: TextButton.styleFrom(foregroundColor: WEAColors.offWhite),
            child: const Text('VIEW SITE'),
          ),
          TextButton(
            onPressed: () => context.go('/super-admin'),
            style: TextButton.styleFrom(foregroundColor: WEAColors.offWhite),
            child: const Text('ACCOUNTS'),
          ),
          const SizedBox(width: WEAInsets.md),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _nav())),
      body: SafeArea(
        child: !AppEnvironmentConfig.hasApiConfiguration
            ? const _NoApiNotice()
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    SizedBox(
                      width: 262,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: WEAColors.background,
                          border: Border(
                            right: BorderSide(color: WEAColors.border),
                          ),
                        ),
                        child: _nav(),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? WEAInsets.xl : WEAInsets.md,
                              vertical: WEAInsets.xl,
                            ),
                            child: _body(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _body() => switch (_section) {
    _registrations => const CmsRegistrationsView(),
    _settings => const CmsSettingsView(),
    final name => CmsResourceView(
      key: ValueKey(name),
      resource: cmsResourceByName(name),
    ),
  };

  Widget _nav() => ListView(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.md),
    children: [
      _navHeading('Catalogue'),
      for (final resource in cmsResources)
        _navTile(resource.name, resource.plural, resource.icon),
      const Divider(),
      _navHeading('Applications'),
      _navTile(_registrations, 'Registrations', Icons.how_to_reg_outlined),
      const Divider(),
      _navHeading('Site'),
      _navTile(_settings, 'Website copy', Icons.tune_outlined),
    ],
  );

  Widget _navHeading(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(
      WEAInsets.lg,
      WEAInsets.sm,
      WEAInsets.lg,
      WEAInsets.xs,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: WEAColors.mutedText,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _navTile(String name, String label, IconData icon) {
    final active = _section == name;
    return ListTile(
      selected: active,
      selectedTileColor: WEAColors.accent.withValues(alpha: .10),
      leading: Icon(
        icon,
        size: 20,
        color: active ? WEAColors.accent : WEAColors.mutedText,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: active ? WEAColors.primaryText : WEAColors.secondaryText,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      onTap: () {
        setState(() => _section = name);
        if (Scaffold.of(context).hasDrawer) Navigator.of(context).maybePop();
      },
    );
  }
}

/// Content management needs the API; offline there is nothing to manage.
class _NoApiNotice extends StatelessWidget {
  const _NoApiNotice();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(WEAInsets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: WEAColors.mutedText,
            ),
            const SizedBox(height: WEAInsets.md),
            Text(
              'Content management needs the live API',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WEAInsets.xs),
            Text(
              'This build is running against the offline development backend, '
              'which holds no real content. Deploy with WEA_API_BASE_URL set to '
              'manage the catalogue.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: WEAInsets.lg),
            WEAOutlinedButton(
              label: 'BACK TO SITE',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    ),
  );
}
