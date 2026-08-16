import 'package:flutter/material.dart';

/// Google's own rendered button — web only.
///
/// On every other platform the sign-in is started from WEA's own button, so
/// this returns nothing and the caller falls back to it.
Widget googleRenderedButton() => const SizedBox.shrink();
