import 'local_model.dart';

/// Model files the app offers for download (assets/ai/local_models.json,
/// measured in docs/ai-on-device-spike.md).
class LocalModelCatalog {
  const LocalModelCatalog({
    required this.schemaVersion,
    required this.catalogVersion,
    required this.models,
  });

  final int schemaVersion;
  final int catalogVersion;
  final List<LocalModelSpec> models;

  LocalModelSpec? byId(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }

  static LocalModelCatalog fromJson(Map<String, dynamic> json) =>
      LocalModelCatalog(
        schemaVersion: json['schema_version'] as int,
        catalogVersion: json['catalog_version'] as int,
        models: (json['models'] as List<dynamic>)
            .map((m) => LocalModelSpec.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// Indicative speeds in tokens per second, for time estimates until the
/// phone has measured its own.
class LocalSpeed {
  const LocalSpeed({required this.prefillTps, required this.decodeTps});

  final double prefillTps;
  final double decodeTps;

  static LocalSpeed fromJson(Map<String, dynamic> json) => LocalSpeed(
    prefillTps: (json['prefill_tps'] as num).toDouble(),
    decodeTps: (json['decode_tps'] as num).toDouble(),
  );
}

class LocalModelLicense {
  const LocalModelLicense({
    required this.id,
    required this.url,
    required this.gated,
    required this.requiresAcceptance,
  });

  /// SPDX id, e.g. "apache-2.0".
  final String id;
  final String url;

  /// Hugging Face serves the file only to signed-in users who accepted the
  /// license on the model page (a token is then needed).
  final bool gated;

  /// The app shows the license and asks for acceptance before downloading.
  final bool requiresAcceptance;

  static LocalModelLicense fromJson(Map<String, dynamic> json) =>
      LocalModelLicense(
        id: json['id'] as String,
        url: json['url'] as String,
        gated: json['gated'] as bool? ?? false,
        requiresAcceptance: json['requires_acceptance'] as bool? ?? false,
      );
}

/// One downloadable model file, pinned to a Hugging Face revision.
class LocalModelSpec {
  const LocalModelSpec({
    required this.id,
    required this.family,
    required this.displayName,
    required this.engine,
    required this.format,
    required this.modelType,
    required this.quantization,
    required this.url,
    required this.revision,
    required this.sha256,
    required this.sizeBytes,
    required this.ramMinMb,
    required this.ramRecommendedMb,
    required this.contextDefault,
    required this.contextMax,
    this.contextMaxCpu,
    required this.backends,
    this.gpuActivation,
    required this.tokenFactor,
    required this.speed,
    required this.notes,
    required this.license,
    this.recommended = false,
  });

  final String id;
  final String family;
  final String displayName;
  final LocalEngineKind engine;

  /// "litertlm" or "gguf".
  final String format;

  /// The engine package's model type (chat template), e.g. "gemma4".
  final String modelType;
  final String quantization;
  final String url;
  final String revision;
  final String sha256;
  final int sizeBytes;

  /// Total RAM below which the model is not offered as fitting, and from
  /// which it runs comfortably, at the default context.
  final int ramMinMb;
  final int ramRecommendedMb;
  final int contextDefault;
  final int contextMax;

  /// Lower ceiling when the model runs on the CPU (LiteRT-LM needs much
  /// more memory there).
  final int? contextMaxCpu;
  final List<LocalBackend> backends;

  /// Activation type forced on the GPU: LiteRT-LM's float16 default writes
  /// wrong digits on long prompts.
  final String? gpuActivation;

  /// Real tokens per token estimated by the server (3.5 characters each).
  final double tokenFactor;
  final Map<LocalBackend, LocalSpeed> speed;

  /// Language and speed notes by locale ("it", "en").
  final Map<String, String> notes;
  final LocalModelLicense license;
  final bool recommended;

  String get fileName => Uri.parse(url).pathSegments.last;

  /// The label shown and stored server-side: "Gemma 4 E2B · Q4_K_M".
  String get label => '$displayName · $quantization';

  String noteFor(String languageCode) => notes[languageCode] ?? notes['en']!;

  static LocalModelSpec fromJson(Map<String, dynamic> json) {
    final engine = LocalEngineKind.fromWire(json['engine'] as String?);
    if (engine == null) {
      throw FormatException('unknown engine for ${json['id']}');
    }
    return LocalModelSpec(
      id: json['id'] as String,
      family: json['family'] as String,
      displayName: json['display_name'] as String,
      engine: engine,
      format: json['format'] as String,
      modelType: json['model_type'] as String,
      quantization: json['quantization'] as String,
      url: json['url'] as String,
      revision: json['revision'] as String,
      sha256: json['sha256'] as String,
      sizeBytes: json['size_bytes'] as int,
      ramMinMb: json['ram_min_mb'] as int,
      ramRecommendedMb: json['ram_recommended_mb'] as int,
      contextDefault: json['context_default'] as int,
      contextMax: json['context_max'] as int,
      contextMaxCpu: json['context_max_cpu'] as int?,
      backends: (json['backends'] as List<dynamic>)
          .map((b) => LocalBackend.fromWire(b as String))
          .toList(),
      gpuActivation: json['gpu_activation'] as String?,
      tokenFactor: (json['token_factor'] as num).toDouble(),
      speed: {
        for (final e in (json['speed'] as Map<String, dynamic>).entries)
          LocalBackend.fromWire(e.key): LocalSpeed.fromJson(
            e.value as Map<String, dynamic>,
          ),
      },
      notes: (json['notes'] as Map<String, dynamic>).cast<String, String>(),
      license: LocalModelLicense.fromJson(
        json['license'] as Map<String, dynamic>,
      ),
      recommended: json['recommended'] as bool? ?? false,
    );
  }
}
