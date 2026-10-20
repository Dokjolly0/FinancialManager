import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/ai_analysis.dart';
import '../view_models/ai_conversation_controller.dart';
import '../view_models/ai_draft_controller.dart';
import 'ai_prompt_preview_screen.dart';

/// A report and its follow-up conversation (plan.md section 32.7). With
/// [analysisId] null it runs the previewed draft first.
class AiAnalysisScreen extends ConsumerStatefulWidget {
  const AiAnalysisScreen({super.key, this.analysisId});

  final String? analysisId;

  @override
  ConsumerState<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends ConsumerState<AiAnalysisScreen> {
  final _question = TextEditingController();
  final _scroll = ScrollController();

  String get _key => widget.analysisId ?? aiNewRunKey;

  @override
  void initState() {
    super.initState();
    if (widget.analysisId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final draft = ref.read(aiDraftControllerProvider);
        if (draft.request != null && draft.preview != null) {
          ref
              .read(aiConversationControllerProvider(_key).notifier)
              .startRun(
                draft.request!,
                draft.preview!.dataFingerprint,
                target: draft.preview!.target,
              );
        }
      });
    }
  }

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask() {
    final text = _question.text.trim();
    if (text.isEmpty) return;
    ref.read(aiConversationControllerProvider(_key).notifier).ask(text);
    _question.clear();
    FocusScope.of(context).unfocus();
  }

  String _reportText(AiConversationState s) => s.messages
      .where(
        (m) => m.kind == AiMessageKind.report || m.kind == AiMessageKind.answer,
      )
      .map((m) => m.content)
      .join('\n\n---\n\n');

  Future<void> _refreshPreview() async {
    final draft = ref.read(aiDraftControllerProvider);
    final ok = await ref
        .read(aiDraftControllerProvider.notifier)
        .refresh(instructions: draft.request?.instructions);
    if (ok && mounted) context.pushReplacement(AppRoutes.aiPreview);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(aiConversationControllerProvider(_key));
    final controller = ref.read(
      aiConversationControllerProvider(_key).notifier,
    );
    final detail = state.detail;

    // Keep the newest text in view while streaming.
    ref.listen(aiConversationControllerProvider(_key), (prev, next) {
      if (next.isStreaming &&
          _scroll.hasClients &&
          _scroll.position.extentAfter < 200) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail?.summary.title ?? l10n.aiAnalysisTitle,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (detail != null)
            IconButton(
              tooltip: l10n.aiDataSentTitle,
              icon: const Icon(Icons.dataset_outlined),
              onPressed: () => showAiSentDataSheet(context, detail),
            ),
          if (state.messages.any((m) => m.content.isNotEmpty))
            PopupMenuButton<String>(
              onSelected: (action) async {
                final text = _reportText(state);
                if (action == 'copy') {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(l10n.aiCopied)));
                  }
                } else {
                  await SharePlus.instance.share(
                    ShareParams(text: text, subject: detail?.summary.title),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'copy', child: Text(l10n.aiCopyAction)),
                PopupMenuItem(value: 'share', child: Text(l10n.aiShareAction)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _content(context, state, controller)),
          _InputBar(
            controller: _question,
            state: state,
            onSend: _ask,
            onStop: controller.stop,
          ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AiConversationState state,
    AiConversationController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.loadError != null && state.messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: InlineError(
          message: presentError(state.loadError!, l10n).message,
          onRetry: controller.load,
        ),
      );
    }
    final requestError = state.requestError;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (state.detail != null) _Header(detail: state.detail!),
        for (final m in state.messages)
          m.kind == AiMessageKind.question
              ? _QuestionBubble(text: m.content)
              : _AnswerCard(
                  message: m,
                  isStreaming:
                      state.isStreaming && identical(m, state.messages.last),
                ),
        if (state.streamErrorCode != null)
          _ErrorBanner(
            message: localizeErrorCode(l10n, state.streamErrorCode!),
            detail: state.streamErrorMessage,
          ),
        if (requestError != null) ...[
          _ErrorBanner(
            message: presentError(requestError, l10n).message,
            detail:
                requestError is DomainError &&
                    requestError.code.startsWith('AI_PROVIDER_')
                ? requestError.message
                : null,
          ),
          if (requestError is DomainError &&
              requestError.code == 'AI_DATA_CHANGED')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _refreshPreview,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.aiRefreshPreview),
              ),
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final AiAnalysisDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = detail.summary;
    final dates = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final period = s.periodFrom == null
        ? l10n.aiPeriodUntil(dates.format(s.periodTo))
        : '${dates.format(s.periodFrom!)} – ${dates.format(s.periodTo)}';
    final tokens = NumberFormat.compact(
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        [
          period,
          s.model,
          l10n.aiTokensUsed(
            tokens.format(s.inputTokens),
            tokens.format(s.outputTokens),
          ),
          if (s.cost != null)
            l10n.aiCostValue(s.cost!.toStringAsFixed(s.cost! < 0.1 ? 4 : 2)),
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppSpacing.sm,
          left: AppSpacing.xl,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.message, required this.isStreaming});

  final AiMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final waiting = isStreaming && message.content.isEmpty;
    String? note;
    if (message.status == AiStatus.cancelled) note = l10n.aiAnswerStopped;
    if (message.truncated) note = l10n.aiAnswerTruncated;
    if (message.status == AiStatus.failed && message.errorCode != null) {
      note = localizeErrorCode(l10n, message.errorCode!);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting)
              Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.aiThinking),
                ],
              )
            else
              SelectionArea(
                child: GptMarkdown(
                  message.content,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            if (isStreaming && !waiting) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (note != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                note,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              detail == null || detail!.isEmpty ? message : '$message\n$detail',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.state,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final AiConversationState state;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = state.detail;
    final String hint;
    if (state.isStreaming) {
      hint = l10n.aiWaitForAnswer;
    } else if (detail == null) {
      hint = l10n.aiFollowUpUnavailable;
    } else if (!detail.canAskFollowUps) {
      hint = detail.followUpsLeft == 0
          ? l10n.aiFollowUpLimitReached
          : l10n.aiFollowUpUnavailable;
    } else {
      hint = l10n.aiAskFollowUpHint(detail.followUpsLeft);
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: state.canAsk,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            state.isStreaming
                ? IconButton.filledTonal(
                    tooltip: l10n.aiStopAction,
                    icon: const Icon(Icons.stop),
                    onPressed: onStop,
                  )
                : IconButton.filled(
                    tooltip: l10n.aiAskAction,
                    icon: const Icon(Icons.send),
                    onPressed: state.canAsk ? onSend : null,
                  ),
          ],
        ),
      ),
    );
  }
}
