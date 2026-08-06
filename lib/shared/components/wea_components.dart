import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import '../../core/responsive/responsive.dart';
import '../animations/wea_animations.dart';

class WEAButton extends StatelessWidget {
  const WEAButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
    label: Text(label),
  );
}

class WEAOutlinedButton extends StatefulWidget {
  const WEAOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  State<WEAOutlinedButton> createState() => _WEAOutlinedButtonState();
}

class _WEAOutlinedButtonState extends State<WEAOutlinedButton> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: _hovering ? WEAColors.gold : Colors.transparent,
        border: Border.all(color: WEAColors.gold),
      ),
      child: TextButton(
        onPressed: widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: _hovering ? WEAColors.background : WEAColors.gold,
          minimumSize: Size(0, widget.compact ? 34 : 46),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 18,
            vertical: widget.compact ? 7 : 12,
          ),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          widget.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _hovering ? WEAColors.background : WEAColors.gold,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  );
}

class WEATextButton extends StatelessWidget {
  const WEATextButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onPressed, child: Text(label));
}

class WEACard extends StatelessWidget {
  const WEACard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => HoverLift(
    child: Card(
      child: Padding(padding: padding, child: child),
    ),
  );
}

class WEASection extends StatelessWidget {
  const WEASection({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: WEAInsets.section),
    child: child,
  );
}

class WEAContainer extends StatelessWidget {
  const WEAContainer({
    super.key,
    required this.child,
    this.maxWidth = WEAMaxWidths.content,
  });
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      ResponsiveContainer(maxWidth: maxWidth, child: child);
}

class WEABadge extends StatelessWidget {
  const WEABadge({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: WEAColors.gold.withValues(alpha: .14),
      border: Border.all(color: WEAColors.gold.withValues(alpha: .45)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: WEAColors.brightGold),
    ),
  );
}

class WEAChip extends StatelessWidget {
  const WEAChip({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Chip(label: Text(label));
}

class WEAStatCard extends StatelessWidget {
  const WEAStatCard({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => WEACard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: WEAColors.brightGold),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    ),
  );
}

class WEAAvatar extends StatelessWidget {
  const WEAAvatar({super.key, required this.initials});
  final String initials;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: WEAColors.deepGold,
    foregroundColor: WEAColors.primaryText,
    child: Text(initials),
  );
}

class WEALoading extends StatelessWidget {
  const WEALoading({super.key, this.label = 'Loading'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 14),
        Text(label),
      ],
    ),
  );
}

class WEAEmptyState extends StatelessWidget {
  const WEAEmptyState({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, color: WEAColors.gold, size: 42),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class WEAErrorState extends StatelessWidget {
  const WEAErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: WEAColors.error, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          WEAOutlinedButton(label: 'Try again', onPressed: onRetry),
        ],
      ],
    ),
  );
}
