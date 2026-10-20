/// The LLM providers the backend can talk to (plan.md section 32.5).
enum AiProviderKind {
  anthropic('anthropic'),
  openai('openai'),
  gemini('gemini'),
  openaiCompatible('openai_compatible');

  const AiProviderKind(this.wire);

  final String wire;

  bool get requiresBaseUrl => this == AiProviderKind.openaiCompatible;

  /// OpenAI-compatible servers may need no key (a local Ollama).
  bool get requiresApiKey => this != AiProviderKind.openaiCompatible;

  static AiProviderKind fromWire(String value) => AiProviderKind.values
      .firstWhere((k) => k.wire == value, orElse: () => AiProviderKind.openai);
}

/// A stored provider account. The key itself never leaves the server; only
/// [keyHint] (e.g. "sk-…a1b2") does.
class AiCredential {
  const AiCredential({
    required this.id,
    required this.provider,
    this.baseUrl,
    this.model,
    required this.hasKey,
    this.keyHint,
    this.lastTestedAt,
    this.lastTestOk,
  });

  final String id;
  final AiProviderKind provider;
  final String? baseUrl;
  final String? model;
  final bool hasKey;
  final String? keyHint;
  final DateTime? lastTestedAt;
  final bool? lastTestOk;

  static AiCredential fromJson(Map<String, dynamic> json) => AiCredential(
    id: json['id'] as String,
    provider: AiProviderKind.fromWire(json['provider'] as String),
    baseUrl: json['base_url'] as String?,
    model: json['model'] as String?,
    hasKey: json['has_key'] as bool? ?? false,
    keyHint: json['key_hint'] as String?,
    lastTestedAt: _date(json['last_tested_at']),
    lastTestOk: json['last_test_ok'] as bool?,
  );
}

DateTime? _date(Object? raw) => raw is String ? DateTime.parse(raw) : null;

class AiConsent {
  const AiConsent({
    this.acceptedVersion,
    required this.currentVersion,
    this.acceptedAt,
    required this.required,
  });

  final int? acceptedVersion;
  final int currentVersion;
  final DateTime? acceptedAt;

  /// True when the current disclosure was never accepted.
  final bool required;

  static AiConsent fromJson(Map<String, dynamic> json) => AiConsent(
    acceptedVersion: json['accepted_version'] as int?,
    currentVersion: json['current_version'] as int? ?? 1,
    acceptedAt: _date(json['accepted_at']),
    required: json['required'] as bool? ?? true,
  );
}

/// What the setup checklist shows.
class AiSetupStatus {
  const AiSetupStatus({
    this.hasProvider = false,
    this.hasModel = false,
    this.hasContext = false,
    this.walletsTotal = 0,
    this.walletsWithPurpose = 0,
    this.analysesCount = 0,
  });

  final bool hasProvider;
  final bool hasModel;
  final bool hasContext;
  final int walletsTotal;
  final int walletsWithPurpose;
  final int analysesCount;

  bool get providerReady => hasProvider && hasModel;
  bool get purposesDone =>
      walletsTotal > 0 && walletsWithPurpose == walletsTotal;
  bool get hasAnalyses => analysesCount > 0;

  /// Steps done out of [stepCount]: provider, context, purposes, analysis.
  int get stepsDone => [
    providerReady,
    hasContext,
    purposesDone,
    hasAnalyses,
  ].where((d) => d).length;

  static const stepCount = 4;

  static AiSetupStatus fromJson(Map<String, dynamic> json) => AiSetupStatus(
    hasProvider: json['has_provider'] as bool? ?? false,
    hasModel: json['has_model'] as bool? ?? false,
    hasContext: json['has_context'] as bool? ?? false,
    walletsTotal: json['wallets_total'] as int? ?? 0,
    walletsWithPurpose: json['wallets_with_purpose'] as int? ?? 0,
    analysesCount: json['analyses_count'] as int? ?? 0,
  );
}

class AiSettings {
  const AiSettings({
    required this.available,
    this.active,
    this.credentials = const [],
    this.maxOutputTokens = 4096,
    this.inputPricePerMTok,
    this.outputPricePerMTok,
    this.defaultIncludeTransactions = false,
    this.defaultAnonymizeTitles = false,
    required this.consent,
    this.setup = const AiSetupStatus(),
    this.version = 0,
  });

  /// False when the server has no AI_KEY_ENCRYPTION_KEY.
  final bool available;
  final AiCredential? active;
  final List<AiCredential> credentials;
  final int maxOutputTokens;
  final double? inputPricePerMTok;
  final double? outputPricePerMTok;
  final bool defaultIncludeTransactions;
  final bool defaultAnonymizeTitles;
  final AiConsent consent;
  final AiSetupStatus setup;
  final int version;

  bool get isReady => available && setup.providerReady && !consent.required;

  AiCredential? credentialFor(AiProviderKind kind, {String? baseUrl}) {
    for (final c in credentials) {
      if (c.provider == kind &&
          (!kind.requiresBaseUrl || c.baseUrl == baseUrl)) {
        return c;
      }
    }
    return null;
  }

  static AiSettings fromJson(Map<String, dynamic> json) {
    final defaults = json['defaults'] as Map<String, dynamic>? ?? const {};
    return AiSettings(
      available: json['available'] as bool? ?? false,
      active: json['active'] is Map<String, dynamic>
          ? AiCredential.fromJson(json['active'] as Map<String, dynamic>)
          : null,
      credentials: (json['credentials'] as List<dynamic>? ?? const [])
          .map((c) => AiCredential.fromJson(c as Map<String, dynamic>))
          .toList(),
      maxOutputTokens: json['max_output_tokens'] as int? ?? 4096,
      inputPricePerMTok: (json['input_price_per_mtok'] as num?)?.toDouble(),
      outputPricePerMTok: (json['output_price_per_mtok'] as num?)?.toDouble(),
      defaultIncludeTransactions:
          defaults['include_transactions'] as bool? ?? false,
      defaultAnonymizeTitles: defaults['anonymize_titles'] as bool? ?? false,
      consent: AiConsent.fromJson(
        json['consent'] as Map<String, dynamic>? ?? const {},
      ),
      setup: AiSetupStatus.fromJson(
        json['setup'] as Map<String, dynamic>? ?? const {},
      ),
      version: json['version'] as int? ?? 0,
    );
  }
}

/// PUT /v1/ai/settings. [apiKey] null keeps the stored key, '' removes it.
class SaveAiSettingsParams {
  const SaveAiSettingsParams({
    required this.provider,
    this.baseUrl = '',
    required this.model,
    this.apiKey,
    required this.maxOutputTokens,
    this.inputPricePerMTok,
    this.outputPricePerMTok,
    this.defaultIncludeTransactions = false,
    this.defaultAnonymizeTitles = false,
    required this.expectedVersion,
  });

  final AiProviderKind provider;
  final String baseUrl;
  final String model;
  final String? apiKey;
  final int maxOutputTokens;
  final double? inputPricePerMTok;
  final double? outputPricePerMTok;
  final bool defaultIncludeTransactions;
  final bool defaultAnonymizeTitles;
  final int expectedVersion;

  Map<String, dynamic> toJson() => {
    'provider': provider.wire,
    'base_url': baseUrl,
    'model': model,
    if (apiKey != null) 'api_key': apiKey,
    'max_output_tokens': maxOutputTokens,
    'input_price_per_mtok': inputPricePerMTok,
    'output_price_per_mtok': outputPricePerMTok,
    'defaults': {
      'include_transactions': defaultIncludeTransactions,
      'anonymize_titles': defaultAnonymizeTitles,
    },
    'version': expectedVersion,
  };
}

/// What to probe with test-connection / model listing. All fields empty
/// probes the saved configuration; otherwise missing fields fall back to
/// the stored credential for that provider.
class AiProbeParams {
  const AiProbeParams({this.provider, this.baseUrl, this.apiKey, this.model});

  final AiProviderKind? provider;
  final String? baseUrl;
  final String? apiKey;
  final String? model;

  Map<String, dynamic> toJson() => {
    if (provider != null) 'provider': provider!.wire,
    if (baseUrl != null && baseUrl!.isNotEmpty) 'base_url': baseUrl,
    if (apiKey != null && apiKey!.isNotEmpty) 'api_key': apiKey,
    if (model != null && model!.isNotEmpty) 'model': model,
  };
}

class AiTestResult {
  const AiTestResult({
    required this.ok,
    required this.latency,
    this.model,
    this.errorCode,
    this.errorMessage,
  });

  final bool ok;
  final Duration latency;
  final String? model;
  final String? errorCode;
  final String? errorMessage;

  static AiTestResult fromJson(Map<String, dynamic> json) => AiTestResult(
    ok: json['ok'] as bool? ?? false,
    latency: Duration(milliseconds: json['latency_ms'] as int? ?? 0),
    model: json['model'] as String?,
    errorCode: json['error_code'] as String?,
    errorMessage: json['error_message'] as String?,
  );
}

class AiModelInfo {
  const AiModelInfo({required this.id, required this.displayName});

  final String id;
  final String displayName;

  static AiModelInfo fromJson(Map<String, dynamic> json) => AiModelInfo(
    id: json['id'] as String,
    displayName: json['display_name'] as String? ?? json['id'] as String,
  );
}
