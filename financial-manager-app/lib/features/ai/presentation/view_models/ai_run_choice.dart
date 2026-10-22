import '../../domain/models/ai_settings.dart';
import '../../domain/models/local_model_record.dart';

/// A model an analysis can run with: a stored cloud provider account, or
/// a model installed on this phone. The setup screen lists every one, so
/// switching doesn't mean going back to the settings.
sealed class AiRunChoice {
  const AiRunChoice();

  /// Stable id for the picker.
  String get key;

  bool get isOnDevice => this is AiLocalChoice;
}

final class AiCloudChoice extends AiRunChoice {
  const AiCloudChoice(this.credential);

  final AiCredential credential;

  @override
  String get key => 'cloud:${credential.id}';
}

final class AiLocalChoice extends AiRunChoice {
  const AiLocalChoice(this.record);

  final LocalModelRecord record;

  @override
  String get key => 'local:${record.id}';
}

/// Every model the user can run now: cloud accounts with a model (and a
/// key when the provider needs one) while the cloud path is on, then the
/// installed models when on-device runs are on and the phone has engines.
List<AiRunChoice> aiRunChoices(
  AiSettings settings, {
  required bool localSupported,
  required List<LocalModelRecord> installed,
}) => [
  if (settings.available)
    for (final c in [
      // The server lists the active account among the others; keep it
      // even if a response doesn't.
      if (settings.active != null &&
          !settings.credentials.any((c) => c.id == settings.active!.id))
        settings.active!,
      ...settings.credentials,
    ])
      if ((c.model ?? '').isNotEmpty &&
          (c.hasKey || !c.provider.requiresApiKey))
        AiCloudChoice(c),
  if (settings.onDeviceAvailable && localSupported)
    for (final r in installed) AiLocalChoice(r),
];

/// What the picker starts on: the saved mode's model (the phone's active
/// model on device, the active account in the cloud), else the first one.
AiRunChoice? defaultAiRunChoice(
  List<AiRunChoice> choices,
  AiSettings settings, {
  String? activeLocalModelId,
}) {
  if (choices.isEmpty) return null;
  AiRunChoice? find(bool Function(AiRunChoice) test) {
    for (final c in choices) {
      if (test(c)) return c;
    }
    return null;
  }

  final local = find(
    (c) => c is AiLocalChoice && c.record.id == activeLocalModelId,
  );
  final cloud = find(
    (c) => c is AiCloudChoice && c.credential.id == settings.active?.id,
  );
  if (settings.mode == AiMode.onDevice) {
    return local ?? find((c) => c.isOnDevice) ?? cloud ?? choices.first;
  }
  return cloud ?? find((c) => !c.isOnDevice) ?? local ?? choices.first;
}
