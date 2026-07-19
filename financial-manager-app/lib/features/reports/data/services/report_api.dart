import 'package:dio/dio.dart';

import '../../domain/repositories/report_repository.dart';

/// Thin wrapper over `/v1/reports/*` (plan.md section 14.9). Returns raw
/// decoded JSON.
class ReportApi {
  ReportApi(this._dio);

  final Dio _dio;

  Map<String, dynamic> _commonParams(ReportQuery query) {
    final period = query.period;
    return {
      'preset': period.preset.toApi(),
      if (period.customFrom != null)
        'from': period.customFrom!.toUtc().toIso8601String(),
      if (period.customTo != null)
        'to': period.customTo!.toUtc().toIso8601String(),
      'include_adjustments': query.includeAdjustments,
    };
  }

  Future<Map<String, dynamic>> summary(ReportQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/summary',
      queryParameters: _commonParams(query),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> timeseries(ReportQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/timeseries',
      queryParameters: _commonParams(query),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> breakdown(
    ReportQuery query, {
    required String groupBy,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/breakdown',
      queryParameters: {..._commonParams(query), 'group_by': groupBy},
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> monthlyComparison(ReportQuery query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/reports/monthly-comparison',
      queryParameters: _commonParams(query),
    );
    return response.data!;
  }
}
