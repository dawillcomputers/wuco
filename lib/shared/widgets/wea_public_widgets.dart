import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../core/responsive/responsive.dart';
import '../../data/models/public_content.dart';
import '../animations/wea_animations.dart';
import '../components/wea_brand.dart';
import '../components/wea_components.dart';
import '../layouts/app_shell.dart';
import 'wea_grid_background.dart';

class WEAPublicPage extends StatelessWidget {
  const WEAPublicPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => WEAAppShell(
    child: WEAGridBackground(
      child: SingleChildScrollView(
        child: Column(children: [child, const WEAFooter()]),
      ),
    ),
  );
}

class WEASectionHeading extends StatelessWidget {
  const WEASectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.actionLabel,
    this.actionPath,
  });
  final String eyebrow;
  final String title;
  final String? description;
  final String? actionLabel;
  final String? actionPath;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: WEAColors.accent,
                letterSpacing: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            if (description != null) ...[
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ],
        ),
      ),
      if (actionLabel != null &&
          actionPath != null &&
          !WEAResponsive.isMobile(context))
        WEATextButton(
          label: '$actionLabel  →',
          onPressed: () => context.go(actionPath!),
        ),
    ],
  );
}

class WEAVisualImage extends StatelessWidget {
  const WEAVisualImage({
    super.key,
    required this.imageUrl,
    required this.alt,
    this.aspectRatio = 4 / 3,
    this.overlay = true,
  });
  final String imageUrl;
  final String alt;
  final double aspectRatio;
  final bool overlay;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(WEAInsets.radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            semanticLabel: alt,
            errorBuilder: (_, _, _) => const _ImageFallback(),
          ),
          if (overlay)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // A light navy scrim for depth; the type sits below the
                  // image rather than on it, so it stays deliberately gentle.
                  colors: [Color(0x000A1E3D), Color(0x2E0A1E3D)],
                ),
              ),
            ),
        ],
      ),
    ),
  ).animate().fadeIn(duration: 500.ms);
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [WEAColors.elevated, WEAColors.background],
      ),
    ),
  );
}

class WEAProgrammeCard extends StatelessWidget {
  const WEAProgrammeCard({super.key, required this.programme});
  final Programme programme;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Container(
      decoration: BoxDecoration(
        color: WEAColors.card.withValues(alpha: .84),
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WEAVisualImage(
            imageUrl: programme.imageUrl,
            alt: programme.title,
            aspectRatio: 16 / 8.5,
          ),
          Padding(
            padding: const EdgeInsets.all(WEAInsets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  programme.category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  programme.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  programme.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      programme.duration,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Text('·'),
                    Text(
                      programme.deliveryMode,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                WEATextButton(
                  label: 'VIEW DETAILS  →',
                  onPressed: () => context.go('/programmes/${programme.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WEAFacultyCard extends StatelessWidget {
  const WEAFacultyCard({super.key, required this.member});
  final FacultyMember member;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WEAVisualImage(
          imageUrl: member.imageUrl,
          alt: member.expertise,
          aspectRatio: .94,
        ),
        const SizedBox(height: 16),
        Container(height: 1, width: 34, color: WEAColors.accent),
        const SizedBox(height: 12),
        Text(member.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          member.role,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: WEAColors.accent),
        ),
        const SizedBox(height: 8),
        Text(member.expertise, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(member.note, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class WEAEventPreview extends StatelessWidget {
  const WEAEventPreview({super.key, required this.event});
  final WEAEvent event;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: WEAColors.border),
        color: WEAColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WEAVisualImage(
            imageUrl: event.imageUrl,
            alt: event.title,
            aspectRatio: 16 / 8,
          ),
          Padding(
            padding: const EdgeInsets.all(WEAInsets.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.date,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  event.format,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  event.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class WEAFooter extends StatelessWidget {
  const WEAFooter({super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(color: WEAColors.navy),
    child: WEAContainer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: ResponsiveBuilder(
          builder: (context, breakpoint) {
            final isMobile = breakpoint == WEABreakpoint.mobile;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WEABrandLockup(height: isMobile ? 88 : 108, onDark: true),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    "Africa's Executive Academy for Leadership, Trade, Investment and Professional Development",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: WEAColors.offWhite.withValues(alpha: .78),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 22,
                  runSpacing: 14,
                  children: [
                    for (final link in const [
                      ('Programmes', '/programmes'),
                      ('Faculty', '/faculty'),
                      ('About', '/about'),
                      ('Admissions', '/admissions'),
                      ('Research', '/research'),
                      ('Events', '/events'),
                      ('Professional Network', '/professional-network'),
                      ('Contact', '/contact'),
                      ('Privacy', '/privacy'),
                      ('Terms', '/terms'),
                    ])
                      TextButton(
                        onPressed: () => context.go(link.$2),
                        style: TextButton.styleFrom(
                          foregroundColor: WEAColors.offWhite,
                        ),
                        child: Text(link.$1.toUpperCase()),
                      ),
                  ],
                ),
                const SizedBox(height: 36),
                Divider(color: WEAColors.offWhite.withValues(alpha: .18)),
                const SizedBox(height: 18),
                Text(
                  isMobile
                      ? '© 2026 WUCO Executive Academy.\nA division of the World United Consumer Organisation.'
                      : '© 2026 WUCO Executive Academy. A division of the World United Consumer Organisation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: WEAColors.offWhite.withValues(alpha: .62),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
