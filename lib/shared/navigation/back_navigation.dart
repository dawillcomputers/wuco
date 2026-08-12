import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

/// Goes back to wherever the visitor actually came from.
///
/// `context.go` does not go back — it replaces the location, so someone who
/// reached an event from the home page, from a search, or from a shared link
/// was sent to the events calendar instead of to the page they were reading.
/// This pops the history when there is history to pop, and only falls back to
/// [fallback] when there is not: a shared link opened in a fresh tab has
/// nowhere of its own to return to.
void weaGoBack(BuildContext context, {required String fallback}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// The standard back control, so every page returns the same way.
class WEABackButton extends StatelessWidget {
  const WEABackButton({
    super.key,
    required this.fallback,
    this.label = 'BACK',
    this.onDark = false,
  });

  /// Where to go when this page was opened directly and has no history.
  final String fallback;
  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => weaGoBack(context, fallback: fallback),
      style: TextButton.styleFrom(
        foregroundColor: onDark ? WEAColors.accentSoft : WEAColors.accent,
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: Text(label),
    ),
  );
}
