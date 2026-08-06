import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class WEABrand extends StatelessWidget {
  const WEABrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: WEAColors.gold),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'W',
          style: TextStyle(
            color: WEAColors.brightGold,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 10),
      if (!compact)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WUCO EXECUTIVE',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
            ),
            Text(
              'ACADEMY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: WEAColors.gold,
                letterSpacing: 2.4,
              ),
            ),
          ],
        ),
    ],
  );
}
