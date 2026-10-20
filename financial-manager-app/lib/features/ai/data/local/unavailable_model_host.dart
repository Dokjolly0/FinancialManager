import '../../domain/local/local_llm_engine.dart';

/// The host used until a model manager provides one (and on platforms
/// without on-device engines): every run fails with
/// [LocalErrorCodes.modelMissing], which the app explains.
class UnavailableLocalModelHost implements LocalModelHost {
  const UnavailableLocalModelHost();

  @override
  Future<LocalSession> acquire() async =>
      throw const LocalEngineException(LocalErrorCodes.modelMissing);

  @override
  void recordSpeed(LocalSession session, LocalGenStats stats) {}
}
