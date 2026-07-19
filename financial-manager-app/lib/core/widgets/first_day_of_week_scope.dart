import 'package:flutter/material.dart';

/// Wraps a date/date-range picker's `builder` so its calendar honors the
/// user's saved "first day of week" preference (plan.md section 7.13),
/// independent of the app's display language. Flutter's calendar widgets
/// derive the week-start purely from the ambient [Locale] (via
/// [MaterialLocalizations.firstDayOfWeekIndex]), so this overrides just
/// the locale for the picker's subtree — en_US starts Sunday, en_GB
/// starts Monday — without changing any displayed text.
Widget firstDayOfWeekScope(
  BuildContext context,
  Widget? child,
  String firstDayOfWeek,
) {
  return Localizations.override(
    context: context,
    locale: Locale('en', firstDayOfWeek == 'monday' ? 'GB' : 'US'),
    child: child,
  );
}
