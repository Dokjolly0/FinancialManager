import 'package:dio/dio.dart';

import '../models/ai_analysis.dart';
import '../models/ai_analysis_request.dart';
import '../models/ai_settings.dart';
import '../models/ai_stream_event.dart';
import '../models/ai_user_context.dart';
import '../models/local_model.dart';

/// Produces the events of a report or follow-up answer, whether a cloud
/// provider writes it (the server streams it) or the phone does.
abstract interface class AiTurnSource {
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  });

  /// [localModelId]: on the phone, the model the report was written with
  /// (used when still installed); ignored in the cloud.
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  });
}

/// AI analysis endpoints (plan.md section 32.4). Every method throws
/// [AppError]s; the streaming ones throw before the first event when the
/// server refuses the request.
abstract class AiRepository implements AiTurnSource {
  Future<AiSettings> getSettings();
  Future<AiSettings> saveSettings(SaveAiSettingsParams params);
  Future<void> deleteCredential(String id);
  Future<AiTestResult> testConnection(AiProbeParams params);
  Future<List<AiModelInfo>> listModels(AiProbeParams params);

  /// [scope] is 'cloud' or 'on_device'.
  Future<void> acceptConsent(int version, {String scope = 'cloud'});
  Future<void> revokeConsent({String scope = 'cloud'});

  Future<AiSettings> setMode(
    AiMode mode, {
    String? localModel,
    required int expectedVersion,
  });

  /// On-device runs (plan.md section 33): the server stores the analysis
  /// and returns what the phone must generate; the phone then submits it.
  Future<AiLocalTurn> prepareLocalAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    required AiLocalRuntime runtime,
  });
  Future<AiLocalTurn> prepareLocalFollowUp(String analysisId, String question);
  Future<AiMessage> submitLocalResult(
    String analysisId,
    String messageId,
    AiLocalResult result,
  );

  Future<AiUserContext> getUserContext();
  Future<AiUserContext> saveUserContext(AiUserContext context);

  Future<List<AiPreset>> listPresets();
  Future<AiPreview> preview(AiAnalysisRequest request);

  /// Runs an analysis previewed with [dataFingerprint]. [clientRequestId]
  /// makes a retry of the same run idempotent.
  @override
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  });

  @override
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  });

  Future<AiHistoryPage> listAnalyses({String? cursor, int limit = 20});
  Future<AiAnalysisDetail> getAnalysis(String id);
  Future<AiAnalysisDetail> renameAnalysis(String id, String title);
  Future<void> deleteAnalysis(String id);
  Future<void> deleteAllAnalyses();
}
