import 'local_model.dart';
import 'local_model_catalog.dart';

/// Where an installed model came from.
enum LocalModelSource {
  catalog('catalog'),
  file('file'),
  url('url');

  const LocalModelSource(this.wire);

  final String wire;

  static LocalModelSource fromWire(String? value) => LocalModelSource.values
      .firstWhere((s) => s.wire == value, orElse: () => LocalModelSource.file);
}

/// What the model registry keeps about an installed model file. The file
/// lives in the model's own folder; [toInstalled] gives the engines' view.
class LocalModelRecord {
  const LocalModelRecord({
    required this.id,
    required this.engine,
    required this.modelType,
    required this.displayName,
    required this.quantization,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.verified,
    required this.source,
    required this.installedAt,
    required this.defaultContextTokens,
    required this.maxContextTokens,
    this.maxContextTokensCpu,
    required this.backends,
    this.tokenFactor,
    this.catalogVersion,
  });

  /// A catalog model just downloaded and verified.
  factory LocalModelRecord.fromSpec(
    LocalModelSpec spec, {
    required int catalogVersion,
    required DateTime installedAt,
  }) => LocalModelRecord(
    id: spec.id,
    engine: spec.engine,
    modelType: spec.modelType,
    displayName: spec.displayName,
    quantization: spec.quantization,
    fileName: spec.fileName,
    sizeBytes: spec.sizeBytes,
    sha256: spec.sha256,
    verified: true,
    source: LocalModelSource.catalog,
    installedAt: installedAt,
    defaultContextTokens: spec.contextDefault,
    maxContextTokens: spec.contextMax,
    maxContextTokensCpu: spec.contextMaxCpu,
    backends: spec.backends,
    tokenFactor: spec.tokenFactor,
    catalogVersion: catalogVersion,
  );

  final String id;
  final LocalEngineKind engine;

  /// The engine package's model type (chat template); "general" for
  /// imports, where the engine reads the template from the file.
  final String modelType;
  final String displayName;
  final String quantization;
  final String fileName;
  final int sizeBytes;

  /// SHA-256 of the file as installed.
  final String sha256;

  /// False for an import whose expected checksum wasn't given.
  final bool verified;
  final LocalModelSource source;
  final DateTime installedAt;
  final int defaultContextTokens;
  final int maxContextTokens;
  final int? maxContextTokensCpu;

  /// Backends offered, the default first.
  final List<LocalBackend> backends;

  /// Null for imports: estimates then use a generic factor.
  final double? tokenFactor;
  final int? catalogVersion;

  String get label => '$displayName · $quantization';

  InstalledLocalModel toInstalled(String path) => InstalledLocalModel(
    id: id,
    engine: engine,
    displayName: displayName,
    quantization: quantization,
    path: path,
    defaultContextTokens: defaultContextTokens,
    maxContextTokens: maxContextTokens,
    maxContextTokensCpu: maxContextTokensCpu,
    modelType: modelType,
    verified: verified,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'engine': engine.wire,
    'model_type': modelType,
    'display_name': displayName,
    'quantization': quantization,
    'file_name': fileName,
    'size_bytes': sizeBytes,
    'sha256': sha256,
    'verified': verified,
    'source': source.wire,
    'installed_at': installedAt.toUtc().toIso8601String(),
    'default_context_tokens': defaultContextTokens,
    'max_context_tokens': maxContextTokens,
    'max_context_tokens_cpu': ?maxContextTokensCpu,
    'backends': backends.map((b) => b.wire).toList(),
    'token_factor': ?tokenFactor,
    'catalog_version': ?catalogVersion,
  };

  static LocalModelRecord? fromJson(Map<String, dynamic> json) {
    final engine = LocalEngineKind.fromWire(json['engine'] as String?);
    if (engine == null) return null;
    return LocalModelRecord(
      id: json['id'] as String,
      engine: engine,
      modelType: json['model_type'] as String? ?? 'general',
      displayName: json['display_name'] as String,
      quantization: json['quantization'] as String? ?? '',
      fileName: json['file_name'] as String,
      sizeBytes: json['size_bytes'] as int,
      sha256: json['sha256'] as String,
      verified: json['verified'] as bool? ?? false,
      source: LocalModelSource.fromWire(json['source'] as String?),
      installedAt: DateTime.parse(json['installed_at'] as String),
      defaultContextTokens: json['default_context_tokens'] as int,
      maxContextTokens: json['max_context_tokens'] as int,
      maxContextTokensCpu: json['max_context_tokens_cpu'] as int?,
      backends:
          (json['backends'] as List<dynamic>?)
              ?.map((b) => LocalBackend.fromWire(b as String))
              .toList() ??
          defaultBackendsFor(engine),
      tokenFactor: (json['token_factor'] as num?)?.toDouble(),
      catalogVersion: json['catalog_version'] as int?,
    );
  }
}

/// Backends for a file outside the catalog: LiteRT-LM bundles on the GPU
/// (float32) with the CPU as the alternative; llama.cpp on the CPU only
/// (its GPU path crashed on Adreno, docs/ai-on-device-spike.md).
List<LocalBackend> defaultBackendsFor(LocalEngineKind engine) =>
    engine == LocalEngineKind.litertLm
    ? const [LocalBackend.gpu, LocalBackend.cpu]
    : const [LocalBackend.cpu];

/// What the user chose for a model's runs; unset fields take the model's
/// defaults.
class LocalRuntimeChoice {
  const LocalRuntimeChoice({
    this.contextTokens,
    this.maxOutputTokens,
    this.temperature,
    this.backend,
  });

  final int? contextTokens;
  final int? maxOutputTokens;
  final double? temperature;
  final LocalBackend? backend;

  Map<String, dynamic> toJson() => {
    'context_tokens': ?contextTokens,
    'max_output_tokens': ?maxOutputTokens,
    'temperature': ?temperature,
    'backend': ?backend?.wire,
  };

  static LocalRuntimeChoice fromJson(Map<String, dynamic> json) =>
      LocalRuntimeChoice(
        contextTokens: json['context_tokens'] as int?,
        maxOutputTokens: json['max_output_tokens'] as int?,
        temperature: (json['temperature'] as num?)?.toDouble(),
        backend: json['backend'] == null
            ? null
            : LocalBackend.fromWire(json['backend'] as String),
      );
}
