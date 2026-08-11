import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_records.dart';

/// Opens global learner search.
///
/// The panel only renders results; matching is delegated to
/// [learnerSearchRepositoryProvider], so replacing local matching with a real
/// index requires no change here.
Future<void> showLearnerSearch(BuildContext context, WidgetRef ref) {
  ref.read(searchQueryProvider.notifier).set('');
  return showDialog<void>(
    context: context,
    barrierColor: WEAColors.navy.withValues(alpha: .34),
    builder: (context) => const _SearchPanel(),
  );
}

class _SearchPanel extends ConsumerStatefulWidget {
  const _SearchPanel();

  @override
  ConsumerState<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<_SearchPanel> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final theme = Theme.of(context);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: WEAInsets.lg,
        vertical: 72,
      ),
      backgroundColor: WEAColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WEAInsets.radius),
        side: const BorderSide(color: WEAColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(WEAInsets.md),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                onChanged: (value) =>
                    ref.read(searchQueryProvider.notifier).set(value),
                decoration: InputDecoration(
                  hintText: 'Search programmes, courses, lessons…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Close search',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: WEAColors.border),
            Flexible(
              child: query.trim().isEmpty
                  ? _Hint(theme: theme)
                  : results.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(WEAInsets.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(WEAInsets.xl),
                        child: Text(
                          'We could not run that search. Please try again.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      data: (items) => items.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(WEAInsets.xl),
                              child: Text(
                                'No matches for "$query".',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                vertical: WEAInsets.xs,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: WEAColors.border,
                              ),
                              itemBuilder: (context, index) =>
                                  _ResultTile(result: items[index]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(WEAInsets.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SEARCH YOUR LEARNING',
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.accent,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(
          'Find programmes, courses, lessons and certificates you are enrolled on.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final LearnerSearchResult result;

  IconData get _icon => switch (result.kind) {
    'Programme' => Icons.workspace_premium_outlined,
    'Course' => Icons.menu_book_outlined,
    'Lesson' => Icons.play_circle_outline,
    _ => Icons.verified_outlined,
  };

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(_icon, color: WEAColors.accent, size: 20),
    title: Text(result.title),
    subtitle: Text(result.subtitle),
    trailing: const Icon(Icons.north_east, size: 16),
    onTap: () {
      Navigator.of(context).pop();
      context.go(result.route);
    },
  );
}
