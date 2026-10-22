import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/ai_analysis.dart';
import '../view_models/ai_history_controller.dart';
import 'ai_pending_results_screen.dart';

/// Saved analyses (plan.md section 32.7): open, rename, delete.
class AiHistoryScreen extends ConsumerWidget {
  const AiHistoryScreen({super.key});

  void _showError(BuildContext context, AppError? e) {
    if (e == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(presentError(e, AppLocalizations.of(context)).message),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) => ConfirmationSheet.show(
    context,
    title: AppLocalizations.of(context).aiDeleteAnalysisTitle,
    confirmLabel: AppLocalizations.of(context).aiDeleteAction,
    isDestructive: true,
  );

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AiAnalysisSummary a,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: a.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.aiCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.aiSaveSettings),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || title == a.title) return;
    final error = await ref
        .read(aiHistoryControllerProvider.notifier)
        .rename(a.id, title);
    if (context.mounted) _showError(context, error);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(aiHistoryControllerProvider);
    final controller = ref.read(aiHistoryControllerProvider.notifier);
    final dates = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiHistoryTitle),
        actions: [
          if (state.items.isNotEmpty)
            IconButton(
              tooltip: l10n.aiDeleteAllAction,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await ConfirmationSheet.show(
                  context,
                  title: l10n.aiDeleteAllTitle,
                  message: l10n.aiDeleteAllMessage,
                  confirmLabel: l10n.aiDeleteAllAction,
                  isDestructive: true,
                );
                if (!ok) return;
                final error = await controller.deleteAll();
                if (context.mounted) _showError(context, error);
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.aiNew),
        icon: const Icon(Icons.auto_awesome),
        label: Text(l10n.aiNewAnalysisTitle),
      ),
      body: Column(
        children: [
          // Results written on this phone that the server doesn't have.
          AiPendingResultsBanner(
            onOpen: () => context.push(AppRoutes.aiPending),
          ),
          Expanded(
            child: state.isLoading
                ? const SkeletonList()
                : state.error != null && state.items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: InlineError(
                      message: presentError(state.error!, l10n).message,
                      onRetry: controller.refresh,
                    ),
                  )
                : state.items.isEmpty
                ? EmptyState(
                    icon: Icons.auto_awesome_outlined,
                    message: l10n.aiHistoryEmpty,
                  )
                : RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.extentAfter < 300) controller.loadMore();
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: state.items.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final a = state.items[i];
                          return Dismissible(
                            key: ValueKey(a.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(
                                right: AppSpacing.lg,
                              ),
                              child: const Icon(Icons.delete_outline),
                            ),
                            confirmDismiss: (_) => _confirmDelete(context),
                            onDismissed: (_) async {
                              final error = await controller.delete(a.id);
                              if (context.mounted) _showError(context, error);
                            },
                            child: ListTile(
                              leading: _StatusIcon(
                                status: a.status,
                                onDevice: a.isOnDevice,
                              ),
                              title: Text(
                                a.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${dates.format(a.createdAt.toLocal())} · ${a.model}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'rename') {
                                    await _rename(context, ref, a);
                                  } else if (await _confirmDelete(context)) {
                                    final error = await controller.delete(a.id);
                                    if (context.mounted) {
                                      _showError(context, error);
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text(l10n.aiRenameAction),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.aiDeleteAction),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  context.push(AppRoutes.aiAnalysis(a.id)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, this.onDevice = false});

  final AiStatus status;

  /// Written on the phone: a phone instead of a document when completed.
  final bool onDevice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      AiStatus.completed => Icon(
        onDevice ? Icons.smartphone_outlined : Icons.description_outlined,
        color: scheme.primary,
      ),
      AiStatus.streaming => const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      AiStatus.cancelled => Icon(
        Icons.stop_circle_outlined,
        color: scheme.outline,
      ),
      AiStatus.failed => Icon(Icons.error_outline, color: scheme.error),
    };
  }
}
