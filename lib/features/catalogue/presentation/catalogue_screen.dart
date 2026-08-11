import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/catalogue_providers.dart';
import 'widgets/catalogue_cards.dart';

/// The public catalogue.
///
/// Areas, types and programmes all come from the API — nothing on this page is
/// compiled in, so publishing a programme in the CMS makes it appear here.
class CatalogueScreen extends ConsumerStatefulWidget {
  const CatalogueScreen({super.key});

  @override
  ConsumerState<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends ConsumerState<CatalogueScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(catalogueOverviewProvider);
    final filter = ref.watch(catalogueFilterProvider);

    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: CatalogueAsync(
            value: overview,
            onRetry: () => ref.invalidate(catalogueOverviewProvider),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEASectionHeading(
                  eyebrow: 'EXECUTIVE EDUCATION',
                  title: data.setting(
                    'catalogue_headline',
                    'Executive programmes for Africa’s leaders',
                  ),
                  description: data.setting(
                    'catalogue_intro',
                    'Executive certificates, masterclasses, short courses and executive short cases, developed for professionals who carry real decisions.',
                  ),
                ),
                const SizedBox(height: WEAInsets.xxl),

                if (data.areas.isEmpty)
                  const _EmptyCatalogue()
                else ...[
                  Text(
                    'FLAGSHIP PROGRAMME AREAS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: WEAInsets.md),
                  CatalogueGrid(
                    children: [
                      for (final area in data.areas) AreaCard(area: area),
                    ],
                  ),
                  const SizedBox(height: WEAInsets.section),

                  Text(
                    'BROWSE EVERY PROGRAMME',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: WEAInsets.md),
                  TextField(
                    controller: _search,
                    onChanged: ref
                        .read(catalogueFilterProvider.notifier)
                        .setQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search programmes',
                      hintText: 'AfCFTA, consumer protection, AI, banking…',
                    ),
                  ),
                  const SizedBox(height: WEAInsets.md),
                  _FilterChips(
                    labels: {
                      '': 'All areas',
                      for (final area in data.areas) area.slug: area.title,
                    },
                    selected: filter.area,
                    onSelected: ref
                        .read(catalogueFilterProvider.notifier)
                        .setArea,
                  ),
                  const SizedBox(height: WEAInsets.xs),
                  _FilterChips(
                    labels: {
                      '': 'All formats',
                      for (final type in data.types) type.slug: type.label,
                    },
                    selected: filter.type,
                    onSelected: ref
                        .read(catalogueFilterProvider.notifier)
                        .setType,
                  ),
                  const SizedBox(height: WEAInsets.xl),
                  const _ProgrammeResults(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: WEAInsets.xs,
    runSpacing: WEAInsets.xs,
    children: [
      for (final entry in labels.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: selected == entry.key,
          showCheckmark: false,
          onSelected: (_) => onSelected(entry.key),
          selectedColor: WEAColors.accent.withValues(alpha: .12),
          side: BorderSide(
            color: selected == entry.key ? WEAColors.accent : WEAColors.border,
          ),
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected == entry.key
                ? WEAColors.accentDeep
                : WEAColors.secondaryText,
          ),
        ),
    ],
  );
}

class _ProgrammeResults extends ConsumerWidget {
  const _ProgrammeResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(filteredCatalogueProvider);
    return CatalogueAsync(
      value: results,
      onRetry: () => ref.invalidate(filteredCatalogueProvider),
      data: (programmes) {
        if (programmes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
            child: Column(
              children: [
                Text(
                  'No programmes match that search.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: WEAInsets.sm),
                WEAOutlinedButton(
                  label: 'CLEAR FILTERS',
                  onPressed: () =>
                      ref.read(catalogueFilterProvider.notifier).clear(),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${programmes.length} programme${programmes.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: WEAInsets.md),
            CatalogueGrid(
              children: [
                for (final programme in programmes)
                  CatalogueProgrammeCard(programme: programme),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Shown before any content is published, so the page never looks broken.
class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
    child: Column(
      children: [
        const Icon(
          Icons.workspace_premium_outlined,
          size: 30,
          color: WEAColors.accent,
        ),
        const SizedBox(height: WEAInsets.sm),
        Text(
          'The programme catalogue is being prepared.',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(
          'New executive programmes are published here as each intake opens.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
