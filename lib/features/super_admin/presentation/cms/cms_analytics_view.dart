import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../events/application/events_providers.dart';
import '../../../events/data/events_repository.dart';

/// Page visitation and campaign performance.
///
/// What it measures and what it deliberately does not: there is no cookie, no
/// cross-site identifier and no stored address. A visitor is counted through a
/// salted digest that rotates daily, which is enough to say how many people
/// came and useless for following any of them.
class CmsAnalyticsView extends ConsumerStatefulWidget {
  const CmsAnalyticsView({super.key});

  @override
  ConsumerState<CmsAnalyticsView> createState() => _CmsAnalyticsViewState();
}

class _CmsAnalyticsViewState extends ConsumerState<CmsAnalyticsView> {
  var _days = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final analytics = ref.watch(siteAnalyticsProvider(_days));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Site analytics', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Where visitors come from, what they read and which campaigns work.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: WEAInsets.lg),
        Wrap(
          spacing: WEAInsets.xs,
          children: [
            for (final option in const [7, 30, 90])
              ChoiceChip(
                label: Text('Last $option days'),
                selected: _days == option,
                onSelected: (_) => setState(() => _days = option),
              ),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        analytics.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(WEAInsets.xl),
            child: Text(
              error is EventFailure
                  ? error.message
                  : 'We could not load site analytics.',
              textAlign: TextAlign.center,
            ),
          ),
          data: (data) => _Report(data: data, days: _days),
        ),
        const SizedBox(height: WEAInsets.xxl),
        const _ShareLinksPanel(),
      ],
    );
  }
}

List<Map<String, dynamic>> _rows(Object? value) => [
  for (final row in (value as List? ?? const []))
    Map<String, dynamic>.from(row as Map),
];

int _count(Map<String, dynamic> row, String key) =>
    (row[key] as num?)?.toInt() ?? 0;

class _Report extends StatelessWidget {
  const _Report({required this.data, required this.days});

  final Map<String, dynamic> data;
  final int days;

  @override
  Widget build(BuildContext context) {
    final series = _rows(data['series']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The two numbers that answer "how are we doing" without a chart.
        Row(
          children: [
            Expanded(
              child: _HeroNumber(
                label: 'Visitors',
                value: '${(data['visitors'] as num?)?.toInt() ?? 0}',
                caption: 'unique, last $days days',
              ),
            ),
            const SizedBox(width: WEAInsets.md),
            Expanded(
              child: _HeroNumber(
                label: 'Page views',
                value: '${(data['views'] as num?)?.toInt() ?? 0}',
                caption: 'across the whole site',
              ),
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.lg),
        if (series.isNotEmpty) _DailyVisitors(series: series),
        const SizedBox(height: WEAInsets.lg),
        _Table(
          title: 'Most visited pages',
          rows: _rows(data['pages']),
          label: (row) => '${row['path'] ?? ''}',
          value: (row) => '${_count(row, 'visitors')} visitors',
          secondary: (row) => '${_count(row, 'views')} views',
        ),
        _Table(
          title: 'Where visitors came from',
          rows: _rows(data['referrers']),
          label: (row) => '${row['source'] ?? ''}',
          value: (row) => '${_count(row, 'views')} views',
          emptyMessage:
              'No referrers recorded yet. Share a campaign link to start '
              'attributing traffic.',
        ),
        _Table(
          title: 'Campaigns',
          rows: _rows(data['campaigns']),
          label: (row) => [
            '${row['source'] ?? ''}',
            '${row['medium'] ?? ''}',
            '${row['campaign'] ?? ''}',
          ].where((part) => part.isNotEmpty).join(' · '),
          value: (row) => '${_count(row, 'visitors')} visitors',
          secondary: (row) => '${_count(row, 'views')} views',
          emptyMessage: 'No campaign traffic yet.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Table(
                title: 'Devices',
                rows: _rows(data['devices']),
                label: (row) => '${row['device'] ?? ''}',
                value: (row) => '${_count(row, 'views')}',
              ),
            ),
            const SizedBox(width: WEAInsets.md),
            Expanded(
              child: _Table(
                title: 'Countries',
                rows: _rows(data['countries']),
                label: (row) => '${row['country'] ?? ''}',
                value: (row) => '${_count(row, 'views')}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.displaySmall),
          const SizedBox(height: 2),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Daily unique visitors.
///
/// One measure only. Views are in the tooltip rather than on a second axis,
/// because two scales on one plot is the fastest way to mislead a reader.
class _DailyVisitors extends StatelessWidget {
  const _DailyVisitors({required this.series});

  final List<Map<String, dynamic>> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = series.fold<int>(
      1,
      (highest, row) =>
          _count(row, 'visitors') > highest ? _count(row, 'visitors') : highest,
    );

    return Container(
      padding: const EdgeInsets.all(WEAInsets.lg),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The title names the series, so no legend is needed for one measure.
          Text('Daily visitors', style: theme.textTheme.titleMedium),
          const SizedBox(height: WEAInsets.md),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final row in series)
                  Expanded(
                    child: Padding(
                      // A surface gap between bars rather than a border.
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message:
                            '${row['day']}\n${_count(row, 'visitors')} visitors'
                            ' · ${_count(row, 'views')} views',
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor:
                                (_count(row, 'visitors') / peak).clamp(0.02, 1.0),
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                color: WEAColors.accent,
                                // Rounded only at the data end; the base stays
                                // anchored to the baseline.
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.xs),
          const Divider(height: 1, color: WEAColors.border),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${series.first['day'] ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
              Text(
                'peak $peak',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
              Text(
                '${series.last['day'] ?? ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.title,
    required this.rows,
    required this.label,
    required this.value,
    this.secondary,
    this.emptyMessage,
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) value;
  final String Function(Map<String, dynamic>)? secondary;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: WEAInsets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: WEAInsets.xs),
          if (rows.isEmpty)
            Text(
              emptyMessage ?? 'Nothing recorded in this period.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(row),
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (secondary != null) ...[
                      Text(
                        secondary!(row),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: WEAColors.mutedText,
                        ),
                      ),
                      const SizedBox(width: WEAInsets.md),
                    ],
                    Text(
                      value(row),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Campaign links and how they have performed.
///
/// Each link is a short URL the academy can put on LinkedIn, Facebook, YouTube
/// or in a newsletter. Following one attaches its campaign parameters before
/// the visitor reaches the page, so the registration it produces is attributed
/// to the channel that produced it.
class _ShareLinksPanel extends ConsumerWidget {
  const _ShareLinksPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final links = ref.watch(shareLinksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Campaign links', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(
          'Create these under Promotion → Campaign links, then share the short '
          'URL. Clicks and landings are counted per link.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: WEAInsets.md),
        links.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(WEAInsets.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text(
            'We could not load campaign links.',
            style: theme.textTheme.bodySmall,
          ),
          data: (data) {
            final rows = _rows(data['links']);
            final origin = '${data['api_origin'] ?? ''}';
            if (rows.isEmpty) {
              return Text(
                'No campaign links yet.',
                style: theme.textTheme.bodySmall,
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  _ShareLinkRow(row: row, origin: origin),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ShareLinkRow extends StatelessWidget {
  const _ShareLinkRow({required this.row, required this.origin});

  final Map<String, dynamic> row;
  final String origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = '$origin/s/${row['code'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: WEAInsets.xs),
      padding: const EdgeInsets.all(WEAInsets.md),
      decoration: BoxDecoration(
        color: WEAColors.card,
        border: Border.all(color: WEAColors.border),
        borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['label'] ?? row['target_path'] ?? ''}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(url, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  [
                    '${row['channel'] ?? ''}',
                    '${row['campaign'] ?? ''}',
                    '${row['target_path'] ?? ''}',
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: WEAColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_count(row, 'clicks')} clicks',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                '${_count(row, 'landings')} landings',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WEAColors.mutedText,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Copy link',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: WEAColors.navy,
                    content: Text('Campaign link copied.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}
