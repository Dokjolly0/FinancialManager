import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/device_capabilities.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_record.dart';

String localBackendLabel(AppLocalizations l10n, LocalBackend b) => switch (b) {
  LocalBackend.gpu => l10n.aiLocalBackendGpu,
  LocalBackend.cpu => l10n.aiLocalBackendCpu,
  LocalBackend.npu => l10n.aiLocalBackendNpu,
};

/// "2,6 GB", "850 MB".
String formatModelBytes(BuildContext context, int bytes) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  const gb = 1024 * 1024 * 1024;
  if (bytes >= gb) {
    return '${NumberFormat('#,##0.0', locale).format(bytes / gb)} GB';
  }
  return '${NumberFormat('#,##0', locale).format(bytes / (1024 * 1024))} MB';
}

/// "16k" tokens.
String formatContextTokens(int tokens) =>
    tokens % 1024 == 0 ? '${tokens ~/ 1024}k' : '$tokens';

/// "Gemma 4 E2B · int4 · GPU · 16k".
String localRuntimeSummary(
  AppLocalizations l10n,
  LocalModelRecord record,
  LocalRuntimeParams params,
) => [
  record.label,
  localBackendLabel(l10n, params.backend),
  l10n.aiLocalContextShort(formatContextTokens(params.contextTokens)),
].join(' · ');

class RamFitChip extends StatelessWidget {
  const RamFitChip({super.key, required this.fit});

  final RamFit fit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (fit) {
      RamFit.fits => (
        l10n.aiLocalRamFits,
        Icons.check_circle_outline,
        scheme.primary,
      ),
      RamFit.tight => (
        l10n.aiLocalRamTight,
        Icons.warning_amber_outlined,
        Colors.amber.shade800,
      ),
      RamFit.insufficient => (
        l10n.aiLocalRamInsufficient,
        Icons.block_outlined,
        scheme.error,
      ),
      RamFit.unknown => (
        l10n.aiLocalRamUnknown,
        Icons.help_outline,
        scheme.outline,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
  }
}

/// Keeps the model label saved on the server in step with the phone's
/// active model while on-device mode is on. Best effort: the label is
/// informational and the next change retries.
Future<void> syncLocalModelLabel(WidgetRef ref, String? label) async {
  try {
    final settings = await ref.read(aiSettingsProvider.future);
    if (settings.mode != AiMode.onDevice || settings.localModel == label) {
      return;
    }
    await ref
        .read(aiRepositoryProvider)
        .setMode(
          AiMode.onDevice,
          localModel: label,
          expectedVersion: settings.version,
        );
    ref.invalidate(aiSettingsProvider);
  } catch (_) {}
}
