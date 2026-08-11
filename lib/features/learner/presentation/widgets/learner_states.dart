import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/animations/wea_animations.dart';
import '../../../../shared/components/wea_components.dart';

/// Section title with optional action, used to head every dashboard block.
class LearnerSectionHeading extends StatelessWidget {
  const LearnerSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Plain white panel used for most dashboard content.
class LearnerCard extends StatelessWidget {
  const LearnerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WEAInsets.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return HoverLift(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WEAInsets.radius),
        child: card,
      ),
    );
  }
}

/// Shimmer-free skeleton: a calm pulsing block, cheaper and less distracting
/// than a moving gradient.
class LearnerSkeleton extends StatefulWidget {
  const LearnerSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 4,
  });

  final double height;
  final double width;
  final double radius;

  @override
  State<LearnerSkeleton> createState() => _LearnerSkeletonState();
}

class _LearnerSkeletonState extends State<LearnerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: Color.lerp(
          WEAColors.elevated,
          WEAColors.border,
          _controller.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Skeleton stand-in for a list of cards.
class LearnerCardSkeleton extends StatelessWidget {
  const LearnerCardSkeleton({super.key, this.count = 3, this.height = 132});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: WEAInsets.sm),
          child: LearnerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LearnerSkeleton(height: 14, width: 120),
                const SizedBox(height: WEAInsets.sm),
                const LearnerSkeleton(height: 20, width: 260),
                const SizedBox(height: WEAInsets.sm),
                LearnerSkeleton(height: height / 6),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Empty state. Deliberately reads as an invitation, not a failure.
class LearnerEmptyState extends StatelessWidget {
  const LearnerEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      padding: const EdgeInsets.symmetric(
        horizontal: WEAInsets.lg,
        vertical: WEAInsets.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(WEAInsets.md),
              decoration: BoxDecoration(
                color: WEAColors.accent.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: WEAColors.accent),
            ),
            const SizedBox(height: WEAInsets.md),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: WEAInsets.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: WEAInsets.lg),
              WEAOutlinedButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state. Never surfaces the underlying exception.
class LearnerErrorState extends StatelessWidget {
  const LearnerErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      padding: const EdgeInsets.symmetric(
        horizontal: WEAInsets.lg,
        vertical: WEAInsets.xl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 26,
              color: WEAColors.mutedText,
            ),
            const SizedBox(height: WEAInsets.sm),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: WEAInsets.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: WEAInsets.md),
              WEAOutlinedButton(label: 'TRY AGAIN', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard message when a repository call fails, per the module brief.
const kLearnerNetworkMessage =
    'Unable to connect. Please check your internet connection and try again.';

/// Renders an [AsyncValue] with consistent loading, error and retry treatment,
/// so no page has to re-implement the three states.
class LearnerAsync<T> extends StatelessWidget {
  const LearnerAsync({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.loading,
    this.errorMessage = kLearnerNetworkMessage,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback onRetry;
  final Widget? loading;
  final String errorMessage;

  @override
  Widget build(BuildContext context) => value.when(
    skipLoadingOnRefresh: false,
    loading: () => loading ?? const LearnerCardSkeleton(),
    error: (_, _) =>
        LearnerErrorState(message: errorMessage, onRetry: onRetry),
    data: data,
  );
}
