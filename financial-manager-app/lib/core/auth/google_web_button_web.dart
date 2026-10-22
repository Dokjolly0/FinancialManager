import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Google's "Continue with Google" button. A tap opens Google's popup;
/// the resulting ID token arrives on GoogleSignInService.webIdTokens.
/// GoogleSignInService.prepareWebButton must have been called first.
class GoogleWebSignInButton extends StatelessWidget {
  const GoogleWebSignInButton({super.key, this.locale});

  /// The button's language, e.g. "it"; null follows the browser.
  final String? locale;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        type: gsi.GSIButtonType.standard,
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.pill,
        minimumWidth: 280,
        locale: locale,
      ),
    ),
  );
}
