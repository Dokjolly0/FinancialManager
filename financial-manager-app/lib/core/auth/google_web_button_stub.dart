import 'package:flutter/widgets.dart';

/// Nothing outside the browser: the app uses the native flow.
class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({super.key, this.locale});

  final String? locale;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
