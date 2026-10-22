import 'package:shared_preferences/shared_preferences.dart';

/// The model each account last ran an analysis with on this phone
/// (AiRunChoice.key: a cloud account or a phone model), so the setup
/// screen starts there next time. Device-local: phone models only exist
/// here, and the choice is a convenience, not account data.
abstract interface class AiLastChoiceStore {
  Future<String?> read(String userId);
  Future<void> write(String userId, String choiceKey);
}

class SharedPrefsAiLastChoiceStore implements AiLastChoiceStore {
  const SharedPrefsAiLastChoiceStore();

  static String _key(String userId) => 'ai.last_run_choice.$userId';

  @override
  Future<String?> read(String userId) async =>
      (await SharedPreferences.getInstance()).getString(_key(userId));

  @override
  Future<void> write(String userId, String choiceKey) async =>
      (await SharedPreferences.getInstance()).setString(
        _key(userId),
        choiceKey,
      );
}
