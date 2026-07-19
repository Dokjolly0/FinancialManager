import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/report_breakdown.dart';
import '../../domain/models/report_monthly_comparison.dart';
import '../../domain/models/report_summary.dart';
import '../../domain/models/report_timeseries.dart';
import '../../domain/repositories/report_repository.dart';
import '../services/report_api.dart';

/// Only EUR is supported by the app (plan.md section 4.3, enforced at
/// registration/transaction creation) — the timeseries/breakdown/monthly
/// endpoints don't echo a currency back, unlike summary, so it's assumed
/// here rather than round-tripped, matching the same hardcoding already
/// used in HistoryScreen's day-group totals.
const _currency = 'EUR';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl(this._api);

  final ReportApi _api;

  @override
  Future<ReportSummary> summary(ReportQuery query) async {
    try {
      final json = await _api.summary(query);
      return ReportSummary.fromJson(json);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<ReportTimeseries> timeseries(ReportQuery query) async {
    try {
      final json = await _api.timeseries(query);
      return ReportTimeseries.fromJson(json, currency: _currency);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<ReportBreakdown> breakdown(
    ReportQuery query, {
    required String groupBy,
  }) async {
    try {
      final json = await _api.breakdown(query, groupBy: groupBy);
      return ReportBreakdown.fromJson(json, currency: _currency);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<ReportMonthlyComparison> monthlyComparison(ReportQuery query) async {
    try {
      final json = await _api.monthlyComparison(query);
      return ReportMonthlyComparison.fromJson(json, currency: _currency);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
