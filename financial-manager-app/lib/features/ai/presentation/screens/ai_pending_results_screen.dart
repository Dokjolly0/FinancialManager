import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';

import '../../../../app/session/current_user_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/local/local_result_outbox.dart';
import '../../data/providers.dart';

/// Reports and answers written on this phone that the server doesn't have
/// yet (plan.md section 33.9): offline when they finished, or refused.
/// Anyone using the app here can read them; only the account that wrote
/// one can send it again or delete it.
class AiPendingResultsScreen extends ConsumerStatefulWidget {
  const AiPendingResultsScreen({super.key});

  @override
  ConsumerState<AiPendingResultsScreen> createState() =>
      _AiPendingResultsScreenState();
}

class _AiPendingResultsScreenState
    extends ConsumerState<AiPendingResultsScreen> {
  final _busy = <String>{};

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _resend(PendingLocalResult item, String userId) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(item.messageId));
    final outcome = await ref
        .read(localResultOutboxProvider)
        .resend(ref.read(aiRepositoryProvider), userId, item.messageId);
    if (!mounted) return;
    setState(() => _busy.remove(item.messageId));
    ref.invalidate(localPendingResultsProvider);
    _snack(switch (outcome) {
      LocalResendOutcome.sent => l10n.aiPendingSent,
      LocalResendOutcome.refused => l10n.aiPendingRefusedAgain,
      LocalResendOutcome.failed => l10n.errorCodeNetworkError,
      LocalResendOutcome.notOwner => l10n.aiPendingNotOwner,
    });
  }

  Future<void> _delete(PendingLocalResult item, String userId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.aiPendingDeleteTitle,
      message: l10n.aiPendingDeleteMessage,
      confirmLabel: l10n.aiDeleteAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(localResultOutboxProvider).remove(userId, item.messageId);
    ref.invalidate(localPendingResultsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserProvider)?.id;
    final itemsAsync = ref.watch(localPendingResultsProvider);
    final dates = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiPendingTitle)),
      body: switch (itemsAsync) {
        AsyncData(value: final items) when items.isEmpty => EmptyState(
          icon: Icons.cloud_done_outlined,
          message: l10n.aiPendingEmpty,
        ),
        AsyncData(value: final items) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(l10n.aiPendingIntro, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final item in items.reversed)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ExpansionTile(
                  leading: Icon(
                    item.refusedCode == null
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_off_outlined,
                    color: item.refusedCode == null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  title: Text(
                    item.isReport ? l10n.aiPendingReport : l10n.aiPendingAnswer,
                  ),
                  subtitle: Text(
                    [
                      dates.format(item.createdAt.toLocal()),
                      item.ownerName ?? l10n.aiPendingUnknownOwner,
                      ?item.modelLabel,
                    ].join(' · '),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.refusedCode == null
                          ? l10n.aiPendingWaiting
                          : l10n.aiPendingRefused(
                              localizeErrorCode(l10n, item.refusedCode!),
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.refusedCode == null
                            ? null
                            : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectionArea(
                      child: GptMarkdown(
                        item.result.content.isEmpty ? '—' : item.result.content,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (item.userId == userId)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy.contains(item.messageId)
                                ? null
                                : () => _delete(item, userId!),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            child: Text(l10n.aiDeleteAction),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          FilledButton.tonal(
                            onPressed: _busy.contains(item.messageId)
                                ? null
                                : () => _resend(item, userId!),
                            child: Text(l10n.aiPendingResend),
                          ),
                        ],
                      )
                    else
                      Text(
                        l10n.aiPendingOwnerOnly(
                          item.ownerName ?? l10n.aiPendingUnknownOwner,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
          ],
        ),
        AsyncError() => Center(child: Text(l10n.errorCodeUnknownError)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// The entry to [AiPendingResultsScreen], shown above the history while
/// something waits on this phone.
class AiPendingResultsBanner extends ConsumerWidget {
  const AiPendingResultsBanner({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(localPendingResultsProvider).value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.cloud_upload_outlined,
          color: scheme.onTertiaryContainer,
        ),
        title: Text(
          AppLocalizations.of(context).aiPendingBanner(items.length),
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: onOpen,
      ),
    );
  }
}
