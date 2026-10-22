import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'google_sign_in_service.dart';
import 'google_web_button.dart';

/// On the web: a dialog with Google's button, closed with the ID token of
/// the account picked in Google's popup, or null if dismissed.
Future<String?> showGoogleWebSignInDialog(
  BuildContext context,
  GoogleSignInService google, {
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _GoogleWebSignInDialog(google: google, title: title),
  );
}

class _GoogleWebSignInDialog extends StatefulWidget {
  const _GoogleWebSignInDialog({required this.google, required this.title});

  final GoogleSignInService google;
  final String title;

  @override
  State<_GoogleWebSignInDialog> createState() => _GoogleWebSignInDialogState();
}

class _GoogleWebSignInDialogState extends State<_GoogleWebSignInDialog> {
  StreamSubscription<String>? _tokens;

  @override
  void initState() {
    super.initState();
    widget.google.prepareWebButton();
    _tokens = widget.google.webIdTokens.listen((token) {
      if (mounted) Navigator.of(context).pop(token);
    });
  }

  @override
  void dispose() {
    _tokens?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Center(
        heightFactor: 1,
        child: GoogleWebSignInButton(locale: l10n.localeName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
