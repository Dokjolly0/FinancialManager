import 'package:flutter/material.dart';

/// Generated avatar: initials of first/last name over a saved background
/// color (plan.md section 7.14). No file is ever produced for this mode —
/// only [backgroundColor]/[textColor] are persisted, and the initials
/// recompute automatically whenever the name changes.
class GeneratedAvatar extends StatelessWidget {
  const GeneratedAvatar({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.backgroundColor,
    required this.textColor,
    this.radius = 24,
  });

  final String firstName;
  final String lastName;
  final Color backgroundColor;
  final Color textColor;
  final double radius;

  String get _initials {
    final first = firstName.trim().isNotEmpty ? firstName.trim()[0] : '';
    final last = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        _initials,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
