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
import '../../data/providers.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/ai_stream_event.dart';
import '../view_models/ai_conversation_controller.dart';
import '../view_models/ai_draft_controller.dart';
import '../view_models/local_models_controller.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/local_context_card.dart';
import '../widgets/local_model_labels.dart';
import 'ai_prompt_preview_screen.dart';

/// A report and its follow-up conversation (plan.md section 32.7), or a
/// chat (section 34): the same screen, the chat's first question shown as
/// the first message. With [analysisId] null it runs the previewed draft
/// first.
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

  /// Tells the runner which analysis is on screen: its runs don't notify.
  late final AiVisibleAnalysis _visible;
  String? _visibleId;

  void _setVisible(String? id) {
    if (id == _visibleId) return;
    final previous = _visibleId;
    _visibleId = id;
    Future.microtask(() {
      _visible.hide(previous);
      if (id != null) _visible.show(id);
    });
  }

  @override
  void initState() {
    super.initState();
    _visible = ref.read(aiVisibleAnalysisProvider.notifier);
    _setVisible(widget.analysisId);
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
    final id = _visibleId;
    Future.microtask(() => _visible.hide(id));
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A chat's first question: stored on the analysis, or the draft's while
  /// a new chat runs. Null for reports.
  String? _chatQuestion(AiConversationState state) {
    final detail = state.detail;
    if (detail != null) return detail.summary.isChat ? detail.question : null;
    if (widget.analysisId != null) return null;
    final request = ref.read(aiDraftControllerProvider).request;
    return request?.preset == aiChatPreset ? request?.instructions : null;
  }

  bool _onDevice(AiConversationState state) =>
      state.detail?.summary.isOnDevice ??
      ref.read(aiDraftControllerProvider).preview?.target == AiMode.onDevice;

  /// Leaving while the phone writes: stop it, stay, or let it go on in the
  /// background (plan.md section 33.9).
  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      aiConversationControllerProvider(_key).notifier,
    );
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiLeaveTitle),
        content: Text(l10n.aiLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.stop),
            child: Text(l10n.aiLeaveStop),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.stay),
            child: Text(l10n.aiLeaveStay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.background),
            child: Text(l10n.aiLeaveBackground),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == _LeaveChoice.stay) return;
    if (choice == _LeaveChoice.stop) {
      controller.stop();
    } else {
      controller.continueInBackground();
    }
    if (mounted) context.pop();
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

  /// Whether this phone can continue an on-device analysis, and with which
  /// model: questions are answered on a phone with an engine and a model,
  /// by the report's model when it is still installed.
  ({String? blocked, String? note}) _localFollowUp(
    AppLocalizations l10n,
    AiAnalysisDetail? detail,
  ) {
    if (detail == null || !detail.summary.isOnDevice) {
      return (blocked: null, note: null);
    }
    if (!ref.watch(localAiSupportedProvider)) {
      return (blocked: l10n.aiLocalFollowUpUnsupported, note: null);
    }
    final models = ref.watch(localModelsControllerProvider);
    if (models.isLoading) return (blocked: null, note: null);
    if (models.installed.isEmpty) {
      return (blocked: l10n.aiLocalFollowUpNoModel, note: null);
    }
    final runtime = detail.summary.runtime;
    if (runtime == null || models.installedById(runtime.modelId) != null) {
      return (blocked: null, note: null);
    }
    final active = models.activeModelId == null
        ? null
        : models.installedById(models.activeModelId!);
    return (
      blocked: null,
      note: l10n.aiLocalFollowUpOtherModel(
        '${runtime.displayName} · ${runtime.quantization}',
        active?.label ?? models.installed.first.label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(aiConversationControllerProvider(_key));
    final controller = ref.read(
      aiConversationControllerProvider(_key).notifier,
    );
    final detail = state.detail;
    _setVisible(state.analysisId ?? widget.analysisId);
    final writingOnPhone = state.isStreaming && _onDevice(state);

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

    return PopScope(
      canPop: !writingOnPhone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            detail?.summary.title ??
                (_chatQuestion(state) != null
                    ? l10n.aiChatTitle
                    : l10n.aiAnalysisTitle),
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
                  PopupMenuItem(
                    value: 'share',
                    child: Text(l10n.aiShareAction),
                  ),
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
              local: _localFollowUp(l10n, detail),
            ),
          ],
        ),
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
    // A new run knows its target from the preview; a stored one from its
    // provider.
    final onDevice =
        state.detail?.summary.isOnDevice ??
        ref.read(aiDraftControllerProvider).preview?.target == AiMode.onDevice;
    final chatQuestion = _chatQuestion(state);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (state.detail != null) _Header(detail: state.detail!),
        if (state.isStreaming && onDevice) const _KeepOpenBanner(),
        if (chatQuestion != null) _QuestionBubble(text: chatQuestion),
        for (final m in state.messages)
          m.kind == AiMessageKind.question
              ? _QuestionBubble(text: m.content, attachment: m.attachment)
              : _AnswerCard(
                  message: m,
                  isStreaming:
                      state.isStreaming && identical(m, state.messages.last),
                  liveTool: identical(m, state.messages.last)
                      ? state.liveTool
                      : null,
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
    final runtime = s.runtime;
    if (s.isOnDevice) {
      // Sul dispositivo · model · quantization · backend · token/s · time.
      final report = detail.messages
          .where((m) => m.kind == AiMessageKind.report)
          .firstOrNull;
      final ms = report?.durationMs;
      final out = report?.outputTokens;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.smartphone_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                [
                  period,
                  l10n.aiModeOnDevice,
                  if (runtime != null) ...[
                    runtime.displayName,
                    if (runtime.quantization.isNotEmpty) runtime.quantization,
                    localBackendLabel(l10n, runtime.backend),
                  ] else
                    s.model,
                  if (ms != null && ms > 0 && out != null && out > 0)
                    l10n.aiLocalTokensPerSecond(
                      (out / (ms / 1000)).toStringAsFixed(1),
                    ),
                  if (ms != null && ms > 0)
                    formatLocalDuration(Duration(milliseconds: ms)),
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
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

enum _LeaveChoice { stop, stay, background }

/// The phone writes the text: the user may leave, it notifies at the end.
class _KeepOpenBanner extends StatelessWidget {
  const _KeepOpenBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.smartphone_outlined, color: scheme.onSecondaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context).aiLocalKeepOpen,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({required this.text, this.attachment});

  final String text;

  /// The older transactions sent with a chat question, opened from a chip.
  final String? attachment;

  @override
  Widget build(BuildContext context) {
    final attachment = this.attachment;
    if (attachment == null) return _bubble(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bubble(context),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ActionChip(
            avatar: const Icon(Icons.manage_search, size: 18),
            label: Text(l10n.aiChatAttachmentChip),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (context) => DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.6,
                builder: (context, scroll) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      l10n.aiChatAttachmentTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(
                      attachment,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(BuildContext context) {
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

/// What a chat tool call looks up, for the status line and the searches.
String _toolLabel(AppLocalizations l10n, {required bool sum, String? query}) {
  final q = query?.trim() ?? '';
  if (sum) return q.isEmpty ? l10n.aiChatToolSumAll : l10n.aiChatToolSum(q);
  return q.isEmpty ? l10n.aiChatToolSearchAll : l10n.aiChatToolSearch(q);
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.message,
    required this.isStreaming,
    this.liveTool,
  });

  final AiMessage message;
  final bool isStreaming;

  /// The search the model is running while this answer streams.
  final AiStreamTool? liveTool;

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
            if (isStreaming && liveTool != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    Icons.manage_search,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _toolLabel(
                        l10n,
                        sum: liveTool!.isSum,
                        query: liveTool!.query,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (isStreaming && !waiting) ...[
              const SizedBox(height: AppSpacing.sm),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (!isStreaming && message.toolTrace.isNotEmpty)
              _Searches(trace: message.toolTrace),
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

/// The searches a chat answer made (section 34.7), with the data the model
/// received.
class _Searches extends StatelessWidget {
  const _Searches({required this.trace});

  final List<AiToolTraceEntry> trace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      leading: const Icon(Icons.manage_search),
      title: Text(
        l10n.aiChatSearchesTitle(trace.length),
        style: theme.textTheme.bodyMedium,
      ),
      children: [
        for (final e in trace)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_toolLabel(l10n, sum: e.isSum, query: e.query)} · '
                  '${l10n.aiChatSearchRows(e.rows)}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(
                  e.result,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
      ],
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
    this.local = (blocked: null, note: null),
  });

  final TextEditingController controller;
  final AiConversationState state;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// On-device analyses: why this phone can't answer ([blocked]), or that a
  /// different model will ([note]).
  final ({String? blocked, String? note}) local;

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
    } else if (local.blocked != null) {
      hint = local.blocked!;
    } else {
      hint = l10n.aiAskFollowUpHint(detail.followUpsLeft);
    }
    final canAsk = state.canAsk && local.blocked == null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (local.note != null && canAsk)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  local.note!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: canAsk,
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
                        onPressed: canAsk ? onSend : null,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
