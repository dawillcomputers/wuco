import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';

/// Standard heading for an inner learner page: eyebrow, title, supporting line
/// and an optional trailing action.
///
/// Every page uses this so the type scale and spacing stay identical across the
/// area rather than drifting page by page.
class LearnerPageHeader extends StatelessWidget {
  const LearnerPageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.trailing,
    this.backRoute,
    this.backLabel,
  });

  final String eyebrow;
  final String title;
  final String? description;
  final Widget? trailing;

  /// Shown as a quiet "back" affordance above the title on detail pages.
  final String? backRoute;
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 700;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (backRoute != null)
          Padding(
            padding: const EdgeInsets.only(bottom: WEAInsets.xs),
            child: _BackLink(route: backRoute!, label: backLabel ?? 'Back'),
          ),
        Text(
          eyebrow.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(title, style: theme.textTheme.headlineMedium),
        if (description != null) ...[
          const SizedBox(height: WEAInsets.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(description!, style: theme.textTheme.bodyLarge),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.lg),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                if (trailing != null) ...[
                  const SizedBox(height: WEAInsets.md),
                  trailing!,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: heading),
                if (trailing != null) ...[
                  const SizedBox(width: WEAInsets.md),
                  trailing!,
                ],
              ],
            ),
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.route, required this.label});

  final String route;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 15, color: WEAColors.accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: WEAColors.accent),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lays children out in a responsive grid without the fixed aspect ratio that
/// makes [GridView.count] clip variable-height cards.
class LearnerResponsiveGrid extends StatelessWidget {
  const LearnerResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 300,
    this.spacing = WEAInsets.md,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / minItemWidth).floor().clamp(1, 4);
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}
