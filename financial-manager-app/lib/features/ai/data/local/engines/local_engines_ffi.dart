import '../../../domain/local/local_llm_engine.dart';
import '../../../domain/models/local_model.dart';
import 'edge_ai_engine.dart';

/// One engine per kind: LiteRT-LM and llama.cpp through flutter_edge_ai.
Map<LocalEngineKind, LocalLlmEngine> createLocalEngines() => {
  for (final kind in LocalEngineKind.values) kind: EdgeAiEngine(kind),
};
