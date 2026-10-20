import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/session/current_user_provider.dart';
import '../../../core/api/providers.dart';
import '../domain/local/local_llm_engine.dart';
import '../domain/models/ai_analysis_request.dart';
import '../domain/models/ai_settings.dart';
import '../domain/models/ai_user_context.dart';
import '../domain/repositories/ai_repository.dart';
import 'local/local_ai_runner.dart';
import 'local/local_result_outbox.dart';
import 'local/unavailable_model_host.dart';
import 'repositories/ai_repository_impl.dart';
import 'services/ai_api.dart';

final aiApiProvider = Provider<AiApi>((ref) {
  return AiApi(ref.watch(apiClientProvider).dio);
});

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(aiApiProvider));
});

/// Cached AI settings (provider, consent, setup checklist), shared by the
/// assistant hub, the Reports entry card and the analysis flow. Registered
/// in user_scoped_providers.dart; invalidate after saving settings,
/// consent, context, a wallet purpose or after an analysis.
final aiSettingsProvider = FutureProvider<AiSettings>((ref) {
  return ref.watch(aiRepositoryProvider).getSettings();
});

/// Cached personal context. Registered in user_scoped_providers.dart.
final aiUserContextProvider = FutureProvider<AiUserContext>((ref) {
  return ref.watch(aiRepositoryProvider).getUserContext();
});

/// Presets in the user's language. Registered in user_scoped_providers.dart
/// since the language follows the account's locale.
final aiPresetsProvider = FutureProvider<List<AiPreset>>((ref) {
  return ref.watch(aiRepositoryProvider).listPresets();
});

/// The phone's model manager (plan.md section 33). Overridden once the
/// model catalog and engines are available; until then every on-device run
/// reports AI_LOCAL_MODEL_MISSING.
final localModelHostProvider = Provider<LocalModelHost>(
  (ref) => const UnavailableLocalModelHost(),
);

/// Results generated on the phone that the server hasn't received yet.
final localResultOutboxProvider = Provider<LocalResultOutbox>(
  (ref) => FileLocalResultOutbox(
    () async => File(
      '${(await getApplicationSupportDirectory()).path}/ai_local/outbox.json',
    ),
  ),
);

/// Not auto-disposed: a run must finish and submit its result even when
/// the screen that started it is gone.
final localAiRunnerProvider = Provider<LocalAiRunner>(
  (ref) => LocalAiRunner(
    repo: ref.watch(aiRepositoryProvider),
    host: ref.watch(localModelHostProvider),
    outbox: ref.watch(localResultOutboxProvider),
    currentUserId: () => ref.read(currentUserProvider)?.id,
  ),
);

/// Where the text of a turn comes from: the server streaming a cloud
/// provider, or the phone.
final aiTurnSourceProvider = Provider.family<AiTurnSource, AiMode>(
  (ref, mode) => mode == AiMode.onDevice
      ? ref.watch(localAiRunnerProvider)
      : ref.watch(aiRepositoryProvider),
);
