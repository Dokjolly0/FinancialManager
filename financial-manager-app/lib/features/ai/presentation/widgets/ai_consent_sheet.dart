import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';

/// The AI analysis disclosure (plan.md section 32.2): what leaves the
/// server, to whom, and how to revoke. Accepting records the current
/// consent version on the backend.
class AiConsentSheet extends ConsumerStatefulWidget {
  const AiConsentSheet({super.key, required this.consentVersion});

  final int consentVersion;

  /// Shows the sheet; true when the user accepted and it was saved.
  static Future<bool> show(
    BuildContext context, {
    required int consentVersion,
  }) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AiConsentSheet(consentVersion: consentVersion),
    );
    return accepted ?? false;
  }

  @override
  ConsumerState<AiConsentSheet> createState() => _AiConsentSheetState();
}

class _AiConsentSheetState extends ConsumerState<AiConsentSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(aiRepositoryProvider).acceptConsent(widget.consentVersion);
      ref.invalidate(aiSettingsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on AppError catch (e) {
      setState(() {
        _saving = false;
        _error = presentError(e, l10n).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget section(IconData icon, String title, List<String> points) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text('• $p', style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(l10n.aiConsentTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.aiConsentIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          section(Icons.upload_outlined, l10n.aiConsentSentTitle, [
            l10n.aiConsentSentAggregates,
            l10n.aiConsentSentWallets,
            l10n.aiConsentSentTransactions,
            l10n.aiConsentSentContext,
          ]),
          section(Icons.block_outlined, l10n.aiConsentNeverTitle, [
            l10n.aiConsentNeverBody,
          ]),
          section(Icons.key_outlined, l10n.aiConsentKeyTitle, [
            l10n.aiConsentKeyBody,
          ]),
          section(Icons.policy_outlined, l10n.aiConsentProviderTitle, [
            l10n.aiConsentProviderBody,
          ]),
          section(Icons.undo, l10n.aiConsentRevokeTitle, [
            l10n.aiConsentRevokeBody,
          ]),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton(
            onPressed: _saving ? null : _accept,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.aiConsentAccept),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.aiConsentDecline),
          ),
        ],
      ),
    );
  }
}
