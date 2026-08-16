import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/services/app_environment.dart';
import '../../../../shared/components/wea_brand.dart';
import '../../../../shared/components/wea_components.dart';
import '../../../../shared/widgets/wea_selectable.dart';
import 'cms_analytics_view.dart';
import 'cms_enquiries_view.dart';
import 'cms_event_registrations_view.dart';
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
  static const _eventRegistrations = '__event_registrations__';
  static const _analytics = '__analytics__';
  static const _enquiries = '__enquiries__';
  static const _settings = '__settings__';

  /// Resources shown under each heading. Anything not listed here falls under
  /// Catalogue, so adding a resource still appears without touching this.
  static const _eventResources = [
    'events',
    'event-registration-fields',
    'event-materials',
    'event-sessions',
  ];
  static const _promotionResources = ['share-links'];

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
        title: const WEABrandLockup(height: 46, onDark: true, linkToHome: true),
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
      // The Builder matters: the drawer's tiles need a context *below* this
      // Scaffold. Built from the state's own context they sit above it, and
      // closing the drawer threw "Scaffold.of() called with a context that
      // does not contain a Scaffold".
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: Builder(builder: (drawer) => _nav(drawerContext: drawer)),
              ),
            ),
      body: WEASelectable(
        child: SafeArea(
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
      ),
    );
  }

  Widget _body() => switch (_section) {
    _registrations => const CmsRegistrationsView(),
    _eventRegistrations => const CmsEventRegistrationsView(),
    _analytics => const CmsAnalyticsView(),
    _enquiries => const CmsEnquiriesView(),
    _settings => const CmsSettingsView(),
    final name => CmsResourceView(
      key: ValueKey(name),
      resource: cmsResourceByName(name),
    ),
  };

  Iterable<CmsResource> _group(List<String> names) =>
      cmsResources.where((resource) => names.contains(resource.name));

  Widget _nav({BuildContext? drawerContext}) => ListView(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.md),
    children: [
      _navHeading('Catalogue'),
      for (final resource in cmsResources)
        if (!_eventResources.contains(resource.name) &&
            !_promotionResources.contains(resource.name))
          _navTile(resource.name, resource.plural, resource.icon, drawerContext),
      const Divider(),
      _navHeading('Events'),
      for (final resource in _group(_eventResources))
        _navTile(resource.name, resource.plural, resource.icon, drawerContext),
      _navTile(
        _eventRegistrations,
        'Event registrations',
        Icons.groups_outlined,
        drawerContext,
      ),
      const Divider(),
      _navHeading('Promotion'),
      for (final resource in _group(_promotionResources))
        _navTile(resource.name, resource.plural, resource.icon, drawerContext),
      _navTile(_analytics, 'Site analytics', Icons.insights_outlined, drawerContext),
      const Divider(),
      _navHeading('Applications'),
      _navTile(_registrations, 'Registrations', Icons.how_to_reg_outlined, drawerContext),
      const Divider(),
      _navHeading('Enquiries'),
      _navTile(_enquiries, 'Contact messages', Icons.forum_outlined, drawerContext),
      const Divider(),
      _navHeading('Site'),
      _navTile(_settings, 'Website copy', Icons.tune_outlined, drawerContext),
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

  Widget _navTile(
    String name,
    String label,
    IconData icon,
    BuildContext? drawerContext,
  ) {
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
        // Closed through the drawer's own context. The state's context sits
        // above the Scaffold, so popping with it would dismiss the whole
        // screen rather than the drawer.
        final drawer = drawerContext;
        if (drawer != null) Scaffold.of(drawer).closeDrawer();
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
