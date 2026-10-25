import '../../../domain/local/local_llm_engine.dart';
import '../../../domain/models/local_model.dart';

/// No engines where dart:ffi is missing.
Map<LocalEngineKind, LocalLlmEngine> createLocalEngines() => const {};
