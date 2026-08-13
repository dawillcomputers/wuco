import 'package:flutter/material.dart';

/// Makes the text inside a page selectable and copyable.
///
/// Flutter paints text to a canvas, so none of it can be selected by default —
/// a visitor could not copy a registration reference, a bank account number or
/// an email address off the page, which on the web is simply broken.
///
/// It belongs on a page shell rather than on the application root: a
/// [SelectionArea] needs an `Overlay` ancestor to place its handles, and at the
/// root it sits above the Navigator that provides one.
class WEASelectable extends StatelessWidget {
  const WEASelectable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(child: child);
}
