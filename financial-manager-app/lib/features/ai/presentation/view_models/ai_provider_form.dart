import '../../domain/models/ai_settings.dart';

/// Suggested base URLs for OpenAI-compatible providers. The user can edit
/// them; Ollama is only a hint since its address depends on the network.
const aiCompatiblePresets = <({String name, String baseUrl})>[
  (name: 'Mistral', baseUrl: 'https://api.mistral.ai/v1'),
  (name: 'Groq', baseUrl: 'https://api.groq.com/openai/v1'),
  (name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1'),
  (name: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1'),
  (name: 'Ollama', baseUrl: 'http://192.168.1.10:11434/v1'),
];

/// Matches the backend limits (ai.MinMaxOutputTokens/MaxMaxOutputTokens).
const aiMinOutputTokens = 256;
const aiMaxOutputTokens = 32000;

/// What the user typed in the provider form.
class AiProviderFormValues {
  const AiProviderFormValues({
    required this.provider,
    this.baseUrl = '',
    this.apiKeyInput = '',
    this.removeStoredKey = false,
    this.model = '',
    this.maxOutputTokens = 4096,
    this.inputPrice,
    this.outputPrice,
    this.includeTransactions = false,
    this.anonymizeTitles = false,
  });

  final AiProviderKind provider;
  final String baseUrl;

  /// A new key typed in the field; empty means "keep the stored one".
  final String apiKeyInput;

  /// The user asked to remove the stored key (keyless compatible servers).
  final bool removeStoredKey;
  final String model;
  final int maxOutputTokens;
  final double? inputPrice;
  final double? outputPrice;
  final bool includeTransactions;
  final bool anonymizeTitles;
}

/// Client-side checks mirroring the backend, keyed like its field errors.
/// [stored] is the credential already saved for this provider/base URL.
Map<String, String> validateAiProviderForm(
  AiProviderFormValues v, {
  AiCredential? stored,
}) {
  final errors = <String, String>{};
  if (v.provider.requiresBaseUrl && v.baseUrl.trim().isEmpty) {
    errors['base_url'] = 'REQUIRED_FIELD';
  }
  if (v.model.trim().isEmpty) {
    errors['model'] = 'REQUIRED_FIELD';
  }
  final hasKey =
      v.apiKeyInput.trim().isNotEmpty ||
      (stored?.hasKey == true && !v.removeStoredKey);
  if (v.provider.requiresApiKey && !hasKey) {
    errors['api_key'] = 'REQUIRED_FIELD';
  }
  if (v.maxOutputTokens < aiMinOutputTokens ||
      v.maxOutputTokens > aiMaxOutputTokens) {
    errors['max_output_tokens'] = 'VALUE_OUT_OF_RANGE';
  }
  if ((v.inputPrice ?? 0) < 0) {
    errors['input_price_per_mtok'] = 'NEGATIVE_NOT_ALLOWED';
  }
  if ((v.outputPrice ?? 0) < 0) {
    errors['output_price_per_mtok'] = 'NEGATIVE_NOT_ALLOWED';
  }
  return errors;
}

/// Builds the save request. The key is only sent when it changes: a typed
/// key replaces the stored one, "remove" sends '' and an untouched field
/// sends nothing so the server keeps what it has.
SaveAiSettingsParams buildSaveAiSettingsParams(
  AiProviderFormValues v, {
  required int expectedVersion,
}) {
  final typedKey = v.apiKeyInput.trim();
  return SaveAiSettingsParams(
    provider: v.provider,
    baseUrl: v.provider.requiresBaseUrl ? v.baseUrl.trim() : '',
    model: v.model.trim(),
    apiKey: typedKey.isNotEmpty ? typedKey : (v.removeStoredKey ? '' : null),
    maxOutputTokens: v.maxOutputTokens,
    inputPricePerMTok: v.inputPrice,
    outputPricePerMTok: v.outputPrice,
    defaultIncludeTransactions: v.includeTransactions,
    defaultAnonymizeTitles: v.anonymizeTitles,
    expectedVersion: expectedVersion,
  );
}

/// Probe parameters for "test connection" / "load models" from the form:
/// the typed key if any, otherwise the server falls back to the stored one.
AiProbeParams aiProbeFromForm(AiProviderFormValues v) => AiProbeParams(
  provider: v.provider,
  baseUrl: v.provider.requiresBaseUrl ? v.baseUrl.trim() : null,
  apiKey: v.apiKeyInput.trim(),
  model: v.model.trim(),
);

/// Parses a decimal typed with either a comma or a dot; empty is null.
double? parseAiPrice(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}
