import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../wallets/data/providers.dart';
import '../../../wallets/domain/models/wallet.dart';
import '../../../wallets/domain/models/wallet_type.dart';
import '../../../wallets/domain/repositories/wallet_repository.dart';
import '../../../wallets/presentation/widgets/wallet_icon_data.dart';
import '../../data/providers.dart';

/// Every wallet with its purpose, editable in place (plan.md section
/// 32.3). Saves through the normal wallet update.
class AiWalletPurposesScreen extends ConsumerWidget {
  const AiWalletPurposesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Wallet wallet) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PurposeSheet(wallet: wallet),
    );
    if (saved == true) {
      ref.invalidate(walletsListProvider);
      ref.invalidate(aiSettingsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final walletsAsync = ref.watch(walletsListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiWalletPurposesMenuTitle)),
      body: walletsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: error is AppError
                ? presentError(error, l10n).message
                : l10n.errorCodeUnknownError,
            onRetry: () => ref.invalidate(walletsListProvider),
          ),
        ),
        data: (wallets) {
          if (wallets.isEmpty) {
            return EmptyState(message: l10n.aiWalletPurposesEmpty);
          }
          final withPurpose = wallets.where((w) => w.purpose != null).length;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                l10n.aiWalletPurposesIntro,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.aiWalletPurposesProgress(withPurpose, wallets.length),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: Column(
                  children: [
                    for (final (i, w) in wallets.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorFromHex(w.color),
                          child: Icon(
                            iconForWalletKey(w.icon),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(w.name),
                        subtitle: Text(
                          w.purpose ?? l10n.aiWalletNoPurpose,
                          style: w.purpose == null
                              ? TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontStyle: FontStyle.italic,
                                )
                              : null,
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(context, ref, w),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PurposeSheet extends ConsumerStatefulWidget {
  const _PurposeSheet({required this.wallet});

  final Wallet wallet;

  @override
  ConsumerState<_PurposeSheet> createState() => _PurposeSheetState();
}

class _PurposeSheetState extends ConsumerState<_PurposeSheet> {
  late final TextEditingController _purpose = TextEditingController(
    text: widget.wallet.purpose ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final w = widget.wallet;
    final text = _purpose.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The backend replaces every field on update: send the wallet as it
      // is, with only the purpose changed.
      await ref
          .read(walletRepositoryProvider)
          .updateWallet(
            w.id,
            UpdateWalletParams(
              name: w.name,
              type: w.type,
              icon: w.icon,
              color: w.color,
              expectedVersion: w.version,
              purpose: text.isEmpty ? null : text,
              voucherExpiryCutoffMonth: w.voucherExpiryCutoffMonth,
              voucherExpiryMonth: w.voucherExpiryMonth,
              voucherExpiryDay: w.voucherExpiryDay,
            ),
          );
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
    final suggestions = [
      l10n.aiPurposeSuggestionDaily,
      l10n.aiPurposeSuggestionSavings,
      l10n.aiPurposeSuggestionEmergency,
      l10n.aiPurposeSuggestionHome,
      l10n.aiPurposeSuggestionLeisure,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.wallet.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _purpose,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            maxLength: walletPurposeMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.walletPurposeLabel,
              hintText: l10n.walletPurposeHint,
              errorText: _error,
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final s in suggestions)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _purpose.text = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.aiSavePurpose),
          ),
        ],
      ),
    );
  }
}
