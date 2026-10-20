import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/models/ai_analysis_request.dart';
import '../domain/models/ai_settings.dart';
import '../domain/models/ai_user_context.dart';
import '../domain/repositories/ai_repository.dart';
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
