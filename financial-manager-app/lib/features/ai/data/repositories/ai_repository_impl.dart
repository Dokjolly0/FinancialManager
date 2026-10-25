import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';
import '../../domain/models/ai_settings.dart';
import '../../domain/models/ai_stream_event.dart';
import '../../domain/models/ai_user_context.dart';
import '../../domain/models/local_model.dart';
import '../../domain/repositories/ai_repository.dart';
import '../services/ai_api.dart';

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._api);

  final AiApi _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<AiSettings> getSettings() =>
      _guard(() async => AiSettings.fromJson(await _api.getSettings()));

  @override
  Future<AiSettings> saveSettings(SaveAiSettingsParams params) => _guard(
    () async => AiSettings.fromJson(await _api.saveSettings(params.toJson())),
  );

  @override
  Future<void> deleteCredential(String id) =>
      _guard(() => _api.deleteCredential(id));

  @override
  Future<AiTestResult> testConnection(AiProbeParams params) => _guard(
    () async =>
        AiTestResult.fromJson(await _api.testConnection(params.toJson())),
  );

  @override
  Future<List<AiModelInfo>> listModels(AiProbeParams params) =>
      _guard(() async {
        final raw = await _api.listModels(params.toJson());
        return raw
            .map((m) => AiModelInfo.fromJson(m as Map<String, dynamic>))
            .toList();
      });

  @override
  Future<void> acceptConsent(int version, {String scope = 'cloud'}) =>
      _guard(() => _api.acceptConsent(version, scope));

  @override
  Future<void> revokeConsent({String scope = 'cloud'}) =>
      _guard(() => _api.revokeConsent(scope));

  @override
  Future<AiSettings> setMode(
    AiMode mode, {
    String? localModel,
    required int expectedVersion,
  }) => _guard(
    () async => AiSettings.fromJson(
      await _api.setMode({
        'mode': mode.wire,
        'local_model': localModel,
        'version': expectedVersion,
      }),
    ),
  );

  @override
  Future<AiLocalTurn> prepareLocalAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    required AiLocalRuntime runtime,
  }) => _guard(
    () async => AiLocalTurn.fromJson(
      await _api.prepareLocalAnalysis({
        ...request.toJson(),
        'target': 'on_device',
        'data_fingerprint': dataFingerprint,
        'client_request_id': clientRequestId,
        'runtime': runtime.toJson(),
      }),
    ),
  );

  @override
  Future<AiLocalTurn> prepareLocalFollowUp(
    String analysisId,
    String question,
  ) => _guard(
    () async => AiLocalTurn.fromJson(
      await _api.prepareLocalFollowUp(analysisId, question),
    ),
  );

  @override
  Future<AiMessage> submitLocalResult(
    String analysisId,
    String messageId,
    AiLocalResult result,
  ) => _guard(
    () async => AiMessage.fromJson(
      await _api.submitLocalResult(analysisId, messageId, result.toJson()),
    ),
  );

  @override
  Future<AiUserContext> getUserContext() =>
      _guard(() async => AiUserContext.fromJson(await _api.getUserContext()));

  @override
  Future<AiUserContext> saveUserContext(AiUserContext context) => _guard(
    () async =>
        AiUserContext.fromJson(await _api.saveUserContext(context.toJson())),
  );

  @override
  Future<List<AiPreset>> listPresets() => _guard(() async {
    final raw = await _api.listPresets();
    return raw
        .map((p) => AiPreset.fromJson(p as Map<String, dynamic>))
        .toList();
  });

  @override
  Future<AiPreview> preview(AiAnalysisRequest request) => _guard(
    () async => AiPreview.fromJson(await _api.preview(request.toJson())),
  );

  @override
  Stream<AiStreamEvent> runAnalysis(
    AiAnalysisRequest request, {
    required String dataFingerprint,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) {
    final body = {
      ...request.toJson(),
      'data_fingerprint': dataFingerprint,
      'client_request_id': clientRequestId,
    };
    return _api
        .runAnalysis(body, cancelToken: cancelToken)
        .map(AiStreamEvent.fromSse)
        .where((e) => e != null)
        .cast<AiStreamEvent>();
  }

  @override
  Stream<AiStreamEvent> askFollowUp(
    String analysisId,
    String question, {
    CancelToken? cancelToken,
    String? localModelId,
  }) => _api
      .askFollowUp(analysisId, question, cancelToken: cancelToken)
      .map(AiStreamEvent.fromSse)
      .where((e) => e != null)
      .cast<AiStreamEvent>();

  @override
  Future<AiHistoryPage> listAnalyses({
    String? cursor,
    int limit = 20,
    AiHistoryType? type,
  }) => _guard(
    () async => AiHistoryPage.fromJson(
      await _api.listAnalyses(cursor: cursor, limit: limit, type: type?.wire),
    ),
  );

  @override
  Future<AiAnalysisDetail> getAnalysis(String id) =>
      _guard(() async => AiAnalysisDetail.fromJson(await _api.getAnalysis(id)));

  @override
  Future<AiAnalysisDetail> renameAnalysis(String id, String title) => _guard(
    () async => AiAnalysisDetail.fromJson(await _api.renameAnalysis(id, title)),
  );

  @override
  Future<void> deleteAnalysis(String id) =>
      _guard(() => _api.deleteAnalysis(id));

  @override
  Future<void> deleteAllAnalyses() => _guard(_api.deleteAllAnalyses);
}
