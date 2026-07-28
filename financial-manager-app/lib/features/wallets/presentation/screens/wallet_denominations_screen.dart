import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/wallet_denomination.dart';

/// Cash breakdown editor for a CASH wallet (migration 0022). Always shows
/// one row per fixed EUR denomination (the backend fills in count=0/
/// enabled=true defaults); [WalletDenomination.enabled] lets a user hide
/// denominations they never handle (plan.md: "alcuni utenti non vogliono
/// monete da 1 o 2 centesimi") without losing a previously counted value.
/// Purely informational — never reconciled against the wallet's balance.
class WalletDenominationsScreen extends ConsumerStatefulWidget {
  const WalletDenominationsScreen({super.key, required this.walletId});

  final String walletId;

  @override
  ConsumerState<WalletDenominationsScreen> createState() =>
      _WalletDenominationsScreenState();
}

class _WalletDenominationsScreenState
    extends ConsumerState<WalletDenominationsScreen> {
  List<WalletDenomination>? _rows;
  final Map<int, TextEditingController> _controllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref
          .read(walletRepositoryProvider)
          .getDenominations(widget.walletId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        for (final row in rows) {
          _controllers[row.denominationMinor] = TextEditingController(
            text: row.count.toString(),
          );
        }
        _isLoading = false;
      });
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e;
      });
    }
  }

  void _toggleEnabled(int denominationMinor, bool enabled) {
    setState(() {
      _rows = _rows!
          .map(
            (row) => row.denominationMinor == denominationMinor
                ? row.copyWith(enabled: enabled)
                : row,
          )
          .toList();
    });
  }

  Future<void> _save() async {
    final rows = _rows;
    if (rows == null) return;

    final updated = rows.map((row) {
      final count =
          int.tryParse(_controllers[row.denominationMinor]!.text.trim()) ??
          row.count;
      return row.copyWith(count: count < 0 ? 0 : count);
    }).toList();

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(walletRepositoryProvider)
          .replaceDenominations(widget.walletId, updated);
      if (!mounted) return;
      setState(() {
        _rows = saved;
        _isSaving = false;
      });
      Navigator.of(context).pop();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletDenominationsScreenTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rows == null
          ? Center(
              child: Text(
                _error != null
                    ? presentError(_error!, l10n).message
                    : l10n.denominationsLoadError,
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _rows!.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final row = _rows![index];
                      final label = Money(
                        minorUnits: row.denominationMinor,
                        currency: 'EUR',
                      ).format();
                      return Opacity(
                        opacity: row.enabled ? 1 : 0.5,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                label,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controllers[row.denominationMinor],
                                enabled: row.enabled,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: l10n.denominationCountLabel,
                                  isDense: true,
                                ),
                              ),
                            ),
                            Switch(
                              value: row.enabled,
                              onChanged: (value) =>
                                  _toggleEnabled(row.denominationMinor, value),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      presentError(_error!, l10n).message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.saveDenominationsAction),
                  ),
                ),
              ],
            ),
    );
  }
}
