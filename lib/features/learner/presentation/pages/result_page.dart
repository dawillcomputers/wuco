import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/assessment_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Published results. A table on wide screens, cards on narrow ones — never a
/// table squeezed into a phone.
class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  /// Below this the table becomes a card list.
  static const tableBreakpoint = 820.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asRow = MediaQuery.sizeOf(context).width >= tableBreakpoint;

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearnerPageHeader(
            eyebrow: 'Results',
            title: 'Your results',
            description:
                'Scores and grades released by WEA faculty across your '
                'assessments.',
          ),
          LearnerAsync(
            value: ref.watch(resultsProvider),
            onRetry: () => ref.invalidate(resultsProvider),
            loading: const LearnerCardSkeleton(count: 3, height: 120),
            data: (results) => results.isEmpty
                ? LearnerEmptyState(
                    icon: Icons.grading_outlined,
                    title: 'No results yet',
                    message:
                        'Once an assessment has been marked, your score and '
                        'grade will be published here.',
                    actionLabel: 'VIEW ASSESSMENTS',
                    onAction: () => context.go('/learner/assessments'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (asRow)
                        LearnerCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              const ResultTableHeader(),
                              for (var i = 0; i < results.length; i++)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: i == results.length - 1
                                        ? null
                                        : const Border(
                                            bottom: BorderSide(
                                              color: WEAColors.border,
                                            ),
                                          ),
                                  ),
                                  child: ResultRow(
                                    result: results[i],
                                    asRow: true,
                                  ),
                                ),
                            ],
                          ),
                        )
                      else
                        for (final result in results)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: WEAInsets.sm,
                            ),
                            child: ResultRow(result: result, asRow: false),
                          ),
                      const SizedBox(height: WEAInsets.md),
                      const LearnerLockedNote(
                        message:
                            'Results are issued by WEA. If you believe a mark '
                            'is incorrect, contact your programme office.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
