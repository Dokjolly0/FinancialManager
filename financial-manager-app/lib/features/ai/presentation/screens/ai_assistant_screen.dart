import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_settings.dart';
import '../view_models/local_run_plan.dart';
import '../widgets/ai_consent_sheet.dart';
import '../widgets/ai_provider_labels.dart';

/// Account → Assistente AI (plan.md section 32.7): a setup checklist and
/// the entries to every AI setting.
class AiAssistantScreen extends ConsumerWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(aiSettingsProvider);
    final localSupported = ref.watch(localAiSupportedProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAssistantTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(aiSettingsProvider),
        child: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              InlineError(
                message: error is AppError
                    ? presentError(error, l10n).message
                    : l10n.errorCodeUnknownError,
                onRetry: () => ref.invalidate(aiSettingsProvider),
              ),
            ],
          ),
          // On the web only the cloud path can run.
          data: (settings) =>
              settings.available ||
                  (settings.onDeviceAvailable && localSupported)
              ? _AssistantBody(
                  settings: settings,
                  localSupported: localSupported,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.aiUnavailableTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.aiUnavailableBody, textAlign: TextAlign.center),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AssistantBody extends ConsumerWidget {
  const _AssistantBody({required this.settings, required this.localSupported});

  final AiSettings settings;

  /// Whether this device runs models (false on the web): the account may
  /// be in on-device mode because of the phone.
  final bool localSupported;

  bool get _onDevice =>
      localSupported &&
      settings.onDeviceAvailable &&
      settings.mode == AiMode.onDevice;

  /// The disclosure of the mode in use.
  AiConsent get _consent => _onDevice
      ? (settings.localConsent ?? settings.consent)
      : settings.consent;

  Future<void> _revokeConsent(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.aiConsentRevokeConfirmTitle,
      message: l10n.aiConsentRevokeConfirmMessage,
      confirmLabel: l10n.aiConsentRevokeAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref
          .read(aiRepositoryProvider)
          .revokeConsent(
            scope: _onDevice ? AiMode.onDevice.wire : AiMode.cloud.wire,
          );
      ref.invalidate(aiSettingsProvider);
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e, l10n).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final setup = settings.setup;
    final active = settings.active;
    final consent = _consent;
    final plan = _onDevice ? ref.watch(localRunPlanProvider).value : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SetupChecklist(
          settings: settings,
          onDevice: _onDevice,
          localModelReady: plan != null,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  _onDevice ? Icons.smartphone_outlined : Icons.key_outlined,
                ),
                title: Text(l10n.aiProviderMenuTitle),
                subtitle: Text(
                  _onDevice
                      ? '${l10n.aiModeOnDevice} · ${plan?.record.label ?? l10n.aiLocalNoModelShort}'
                      : active == null
                      ? l10n.aiProviderMenuNotConfigured
                      : '${aiProviderLabel(l10n, active.provider)} · ${active.model ?? '-'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.aiProvider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.aiContextMenuTitle),
                subtitle: Text(
                  setup.hasContext
                      ? l10n.aiContextMenuFilled
                      : l10n.aiContextMenuEmpty,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.aiContext),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: Text(l10n.aiWalletPurposesMenuTitle),
                subtitle: Text(
                  l10n.aiWalletPurposesProgress(
                    setup.walletsWithPurpose,
                    setup.walletsTotal,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.aiWalletPurposes),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.aiHistoryTitle),
            subtitle: Text(l10n.aiHistoryMenuSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiHistory),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: consent.required
              ? ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.aiConsentMenuTitle),
                  subtitle: Text(l10n.aiConsentMenuPending),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => AiConsentSheet.show(
                    context,
                    consentVersion: consent.currentVersion,
                    mode: _onDevice ? AiMode.onDevice : AiMode.cloud,
                  ),
                )
              : ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(l10n.aiConsentMenuTitle),
                  subtitle: Text(l10n.aiConsentMenuAccepted),
                  trailing: TextButton(
                    onPressed: () => _revokeConsent(context, ref),
                    child: Text(l10n.aiConsentRevokeAction),
                  ),
                  onTap: () => AiConsentSheet.show(
                    context,
                    consentVersion: consent.currentVersion,
                    mode: _onDevice ? AiMode.onDevice : AiMode.cloud,
                  ),
                ),
        ),
      ],
    );
  }
}

/// The four setup steps with progress; each undone step links to where it
/// is done. On the phone the first step is an installed model and the
/// on-device disclosure instead of a provider.
class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({
    required this.settings,
    required this.onDevice,
    required this.localModelReady,
  });

  final AiSettings settings;
  final bool onDevice;
  final bool localModelReady;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final setup = settings.setup;
    final providerDone = onDevice
        ? localModelReady && settings.localConsent?.required == false
        : setup.providerReady;
    final done = setup.stepsDoneWith(providerDone);

    Widget step(
      bool isDone,
      String title,
      String subtitle,
      VoidCallback onTap, {
      bool optional = false,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isDone ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(optional ? '$title · ${l10n.aiSetupOptional}' : title),
      subtitle: Text(subtitle),
      trailing: isDone ? null : const Icon(Icons.chevron_right),
      onTap: isDone ? null : onTap,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              done == AiSetupStatus.stepCount
                  ? l10n.aiSetupDoneTitle
                  : l10n.aiSetupTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.aiSetupProgress(done, AiSetupStatus.stepCount),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(value: done / AiSetupStatus.stepCount),
            const SizedBox(height: AppSpacing.sm),
            step(
              providerDone,
              onDevice ? l10n.aiSetupStepLocalModel : l10n.aiSetupStepProvider,
              onDevice
                  ? l10n.aiSetupStepLocalModelHint
                  : l10n.aiSetupStepProviderHint,
              () => context.push(AppRoutes.aiProvider),
            ),
            step(
              setup.hasContext,
              l10n.aiSetupStepContext,
              l10n.aiSetupStepContextHint,
              () => context.push(AppRoutes.aiContext),
              optional: true,
            ),
            step(
              setup.purposesDone,
              l10n.aiSetupStepPurposes,
              l10n.aiSetupStepPurposesHint,
              () => context.push(AppRoutes.aiWalletPurposes),
              optional: true,
            ),
            step(
              setup.hasAnalyses,
              l10n.aiSetupStepFirstAnalysis,
              l10n.aiSetupStepFirstAnalysisHint,
              () => context.push(AppRoutes.aiNew),
            ),
          ],
        ),
      ),
    );
  }
}
