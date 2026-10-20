import 'package:dio/dio.dart';

import '../models/ai_analysis.dart';
import '../models/ai_analysis_request.dart';
import '../models/ai_settings.dart';
import '../models/ai_stream_event.dart';
import '../models/ai_user_context.dart';

/// AI analysis endpoints (plan.md section 32.4). Every method throws
/// [AppError]s; the streaming ones throw before the first event when the
/// server refuses the request.
abstract class AiRepository {
  Future<AiSettings> getSettings();
  Future<AiSettings> saveSettings(SaveAiSettingsParams params);
  Future<void> deleteCredential(String id);
  Future<AiTestResult> testConnection(AiProbeParams params);
  Future<List<AiModelInfo>> listModels(AiProbeParams params);

  Future<void> acceptConsent(int version);
  Future<void> revokeConsent();

  Future<AiUserContext> getUserContext();
  Future<AiUserContext> saveUserContext(AiUserContext context);

  Future<List<AiPreset>> listPresets();
  Future<AiPreview> preview(AiAnalysisRequest request);

  /// Runs an analysis previewed with [dataFingerprint]. [clientRequestId]
  /// makes a retry of the same run idempotent.
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  });

  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
  });

  Future<AiHistoryPage> listAnalyses({String? cursor, int limit = 20});
  Future<AiAnalysisDetail> getAnalysis(String id);
  Future<AiAnalysisDetail> renameAnalysis(String id, String title);
  Future<void> deleteAnalysis(String id);
  Future<void> deleteAllAnalyses();
}
