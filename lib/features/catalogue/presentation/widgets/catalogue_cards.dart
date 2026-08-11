import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_components.dart';
import '../../domain/catalogue_models.dart';

/// Image for a catalogue entry, with a calm fallback when none is set.
class CatalogueImage extends StatelessWidget {
  const CatalogueImage({
    super.key,
    required this.url,
    required this.aspectRatio,
    this.zoomed = false,
  });

  final String? url;
  final double aspectRatio;
  final bool zoomed;

  @override
  Widget build(BuildContext context) {
    final source = url;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        child: source == null
            ? const ColoredBox(
                color: WEAColors.elevated,
                child: Center(
                  child: Icon(
                    Icons.school_outlined,
                    color: WEAColors.mutedText,
                    size: 26,
                  ),
                ),
              )
            : AnimatedScale(
                scale: zoomed ? 1.04 : 1,
                duration: const Duration(milliseconds: 260),
                child: Image.network(
                  source,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: WEAColors.elevated,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: WEAColors.mutedText,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A flagship area on the catalogue landing page.
class AreaCard extends StatefulWidget {
  const AreaCard({super.key, required this.area});

  final ProgrammeArea area;

  @override
  State<AreaCard> createState() => _AreaCardState();
}

class _AreaCardState extends State<AreaCard> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final area = widget.area;
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: () => context.go('/programmes/area/${area.slug}'),
        onFocusChange: (focused) => setState(() => _hovering = focused),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: WEAColors.card,
            border: Border.all(
              color: _hovering ? WEAColors.accent : WEAColors.border,
            ),
            borderRadius: BorderRadius.circular(WEAInsets.radius),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: WEAColors.navy.withValues(alpha: .12),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(WEAInsets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CatalogueImage(
                url: area.imageUrl,
                aspectRatio: 16 / 8,
                zoomed: _hovering,
              ),
              const SizedBox(height: WEAInsets.md),
              Row(
                children: [
                  Text(
                    area.code,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: WEAInsets.xs),
                  Expanded(
                    child: Text(
                      '${area.programmeCount} programmes',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: WEAColors.mutedText,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                area.title,
                style: theme.textTheme.titleLarge,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: WEAInsets.xs),
              Text(
                area.summary,
                style: theme.textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: WEAInsets.md),
              Row(
                children: [
                  Text(
                    'EXPLORE AREA',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: WEAColors.accent,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                  AnimatedSlide(
                    offset: Offset(_hovering ? .35 : 0, 0),
                    duration: const Duration(milliseconds: 220),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 15,
                        color: WEAColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single programme in a catalogue listing.
class CatalogueProgrammeCard extends StatefulWidget {
  const CatalogueProgrammeCard({super.key, required this.programme});

  final CatalogueProgramme programme;

  @override
  State<CatalogueProgrammeCard> createState() => _CatalogueProgrammeCardState();
}

class _CatalogueProgrammeCardState extends State<CatalogueProgrammeCard> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final programme = widget.programme;
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: () => context.go('/programmes/${programme.slug}'),
        onFocusChange: (focused) => setState(() => _hovering = focused),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: WEAColors.card,
            border: Border.all(
              color: _hovering ? WEAColors.accent : WEAColors.border,
            ),
            borderRadius: BorderRadius.circular(WEAInsets.radius),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: WEAColors.navy.withValues(alpha: .10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(WEAInsets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              CatalogueImage(
                url: programme.imageUrl,
                aspectRatio: 16 / 8,
                zoomed: _hovering,
              ),
              const SizedBox(height: WEAInsets.sm),
              Text(
                programme.typeTitle.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.accent,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                programme.title,
                style: theme.textTheme.titleMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                programme.summary,
                style: theme.textTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: WEAInsets.sm),
              Wrap(
                spacing: WEAInsets.sm,
                runSpacing: 4,
                children: [
                  _Meta(icon: Icons.schedule, label: programme.durationLabel),
                  _Meta(
                    icon: Icons.public_outlined,
                    label: programme.deliveryMode,
                  ),
                  _Meta(
                    icon: Icons.payments_outlined,
                    label: programme.tuitionLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: WEAColors.mutedText),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

/// Loading, error and retry treatment shared by every public catalogue page.
class CatalogueAsync<T> extends StatelessWidget {
  const CatalogueAsync({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: false,
    loading: () => const Padding(
      padding: EdgeInsets.symmetric(vertical: WEAInsets.section),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (error, _) => Padding(
      padding: const EdgeInsets.symmetric(vertical: WEAInsets.xxl),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 28,
            color: WEAColors.mutedText,
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(
            'We could not load the catalogue just now.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            'Please check your connection and try again.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: WEAInsets.md),
          WEAOutlinedButton(label: 'TRY AGAIN', onPressed: onRetry),
        ],
      ),
    ),
    data: data,
  );
}

/// Responsive grid that keeps card heights natural instead of clipping them.
class CatalogueGrid extends StatelessWidget {
  const CatalogueGrid({
    super.key,
    required this.children,
    this.minItemWidth = 320,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = WEAInsets.lg;
      final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, 3);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
