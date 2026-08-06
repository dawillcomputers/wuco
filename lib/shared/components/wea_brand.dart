import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class WEABrand extends StatelessWidget {
  const WEABrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 30,
        height: 30,
        child: CustomPaint(painter: _BrandMarkPainter()),
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
              ).textTheme.labelMedium?.copyWith(letterSpacing: 1.35),
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

class _BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WEAColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final inset = size.width * .08;
    canvas.drawRect(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      ),
      paint,
    );
    final path = Path()
      ..moveTo(size.width * .24, size.height * .25)
      ..lineTo(size.width * .39, size.height * .75)
      ..lineTo(size.width * .50, size.height * .42)
      ..lineTo(size.width * .61, size.height * .75)
      ..lineTo(size.width * .76, size.height * .25);
    canvas.drawPath(path, paint..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
