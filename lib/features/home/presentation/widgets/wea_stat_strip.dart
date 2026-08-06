import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../shared/components/wea_components.dart';

class WEAStatStrip extends StatelessWidget {
  const WEAStatStrip({super.key});

  static const _items = [
    ('01', 'BACKED BY WUCO'),
    ('02', 'RIGOROUS CURRICULUM'),
    ('03', 'RESPECTED FACULTY'),
    ('04', 'PAN-AFRICAN REACH'),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: WEAColors.deepBlack,
      border: Border(top: BorderSide(color: WEAColors.border)),
    ),
    child: WEAContainer(
      maxWidth: WEAMaxWidths.content,
      child: ResponsiveBuilder(
        builder: (context, breakpoint) {
          final isDesktop =
              breakpoint == WEABreakpoint.desktop ||
              breakpoint == WEABreakpoint.largeDesktop;
          final columns = isDesktop ? 4 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: isDesktop ? 3.25 : 2.5,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) => _StripItem(
              index: index,
              number: _items[index].$1,
              label: _items[index].$2,
              showLeadingBorder: index % columns != 0,
            ),
          );
        },
      ),
    ),
  );
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.index,
    required this.number,
    required this.label,
    required this.showLeadingBorder,
  });

  final int index;
  final String number;
  final String label;
  final bool showLeadingBorder;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: WEAInsets.lg),
    decoration: BoxDecoration(
      border: Border(
        left: showLeadingBorder
            ? const BorderSide(color: WEAColors.border)
            : BorderSide.none,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: WEAColors.gold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: WEAColors.offWhite,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
