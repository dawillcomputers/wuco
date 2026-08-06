import 'package:flutter/widgets.dart';

enum WEABreakpoint { mobile, tablet, desktop, largeDesktop }

abstract final class WEAResponsive {
  static WEABreakpoint breakpointOf(double width) => switch (width) {
    < 600 => WEABreakpoint.mobile,
    < 1024 => WEABreakpoint.tablet,
    < 1440 => WEABreakpoint.desktop,
    _ => WEABreakpoint.largeDesktop,
  };

  static bool isMobile(BuildContext context) =>
      breakpointOf(MediaQuery.sizeOf(context).width) == WEABreakpoint.mobile;
  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: isMobile(context) ? 20 : 32);
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, WEABreakpoint breakpoint) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        builder(context, WEAResponsive.breakpointOf(constraints.maxWidth)),
  );
}

class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1280,
    this.padding,
  });
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: padding ?? WEAResponsive.pagePadding(context),
        child: child,
      ),
    ),
  );
}

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.spacing = 20});
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
    builder: (context, breakpoint) {
      final columns = switch (breakpoint) {
        WEABreakpoint.mobile => 1,
        WEABreakpoint.tablet => 2,
        _ => 3,
      };
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.35,
        children: children,
      );
    },
  );
}
