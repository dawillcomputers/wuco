import 'package:flutter/material.dart';

import '../../core/responsive/responsive.dart';

/// A grid whose rows are as tall as their content, not a fixed ratio.
///
/// `GridView.count` needs a `childAspectRatio`, which fixes every cell's height
/// from its width. Any cell whose content is shorter than that keeps the
/// difference as dead space beneath it — which is exactly the gap that appears
/// under a faculty portrait or an event card. There is no ratio that is right
/// for every card, because the copy inside them differs.
///
/// This lays the children out row by row instead. Each row is measured from the
/// tallest card in it, and with [stretch] the others match that height, so a
/// row of cards lines up along the bottom without anybody choosing a number.
class WEAAutoGrid extends StatelessWidget {
  const WEAAutoGrid({
    super.key,
    required this.children,
    this.spacing = 24,
    this.runSpacing = 24,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.stretch = true,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;

  /// Whether cards in a row share the tallest one's height. True for cards
  /// with a border or fill, false for plain text blocks, where stretching only
  /// spreads the words out.
  final bool stretch;

  int _columnsFor(double width) => switch (WEAResponsive.breakpointOf(width)) {
    WEABreakpoint.mobile => mobileColumns,
    WEABreakpoint.tablet => tabletColumns,
    _ => desktopColumns,
  };

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth).clamp(1, 6);
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(height: runSpacing),
                children[index],
              ],
            ],
          );
        }

        final rows = <List<Widget>>[];
        for (var start = 0; start < children.length; start += columns) {
          rows.add(
            children.sublist(
              start,
              (start + columns).clamp(0, children.length),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
              if (rowIndex > 0) SizedBox(height: runSpacing),
              _row(rows[rowIndex], columns),
            ],
          ],
        );
      },
    );
  }

  Widget _row(List<Widget> cells, int columns) {
    final row = Row(
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns; index++) ...[
          if (index > 0) SizedBox(width: spacing),
          // A short final row keeps the earlier columns at their proper width
          // rather than letting two cards stretch across the whole measure.
          Expanded(
            child: index < cells.length ? cells[index] : const SizedBox.shrink(),
          ),
        ],
      ],
    );
    // IntrinsicHeight is what lets a row size itself from its tallest card.
    // It is an expensive layout, so it is only used where it earns its keep.
    return stretch ? IntrinsicHeight(child: row) : row;
  }
}
