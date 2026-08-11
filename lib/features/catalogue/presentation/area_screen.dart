import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../shared/components/wea_components.dart';
import '../../../shared/widgets/wea_public_widgets.dart';
import '../application/catalogue_providers.dart';
import 'widgets/catalogue_cards.dart';

/// One flagship area, with its programmes grouped by format.
class AreaScreen extends ConsumerWidget {
  const AreaScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(areaDetailProvider(slug));

    return WEAPublicPage(
      child: WEAContainer(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
          child: CatalogueAsync(
            value: detail,
            onRetry: () => ref.invalidate(areaDetailProvider(slug)),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEATextButton(
                  label: '← All programme areas',
                  onPressed: () => context.go('/programmes'),
                ),
                const SizedBox(height: WEAInsets.sm),
                WEASectionHeading(
                  eyebrow: '${data.area.code}  ${data.area.tagline}',
                  title: data.area.title,
                  description: data.area.summary,
                ),
                const SizedBox(height: WEAInsets.lg),
                CatalogueImage(url: data.area.imageUrl, aspectRatio: 21 / 7),
                if (data.area.description.isNotEmpty) ...[
                  const SizedBox(height: WEAInsets.lg),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Text(
                      data.area.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
                const SizedBox(height: WEAInsets.section),

                if (data.programmes.isEmpty)
                  Text(
                    'Programmes in this area are being prepared and will be published shortly.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  )
                else
                  for (final entry in data.byType.entries) ...[
                    Text(
                      entry.key.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: WEAColors.accent,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: WEAInsets.xs),
                    Text(
                      '${entry.value.length} programme${entry.value.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: WEAInsets.md),
                    CatalogueGrid(
                      children: [
                        for (final programme in entry.value)
                          CatalogueProgrammeCard(programme: programme),
                      ],
                    ),
                    const SizedBox(height: WEAInsets.section),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
