import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper over `/v1/transactions*` and `/v1/wallet/balance-adjustments`
/// (plan.md section 14.4/14.5). Returns raw decoded JSON.
class TransactionApi {
  TransactionApi(this._dio, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Dio _dio;
  final Uuid _uuid;

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/transactions',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/transactions/$id');
    return response.data!;
  }

  Future<Map<String, dynamic>> list({
    String? cursor,
    required int limit,
    String? walletId,
    String? direction,
    String? kind,
    String? categoryId,
    String? title,
    int? amountMinMinor,
    int? amountMaxMinor,
    DateTime? occurredFrom,
    DateTime? occurredTo,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {
        'limit': limit,
        'cursor': ?cursor,
        'wallet_id': ?walletId,
        'direction': ?direction,
        'kind': ?kind,
        'category_id': ?categoryId,
        if (title != null && title.isNotEmpty) 'title': title,
        'amount_min_minor': ?amountMinMinor,
        'amount_max_minor': ?amountMaxMinor,
        if (occurredFrom != null)
          'occurred_from': occurredFrom.toUtc().toIso8601String(),
        if (occurredTo != null)
          'occurred_to': occurredTo.toUtc().toIso8601String(),
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/transactions/$id',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateOpeningBalance(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/transactions/$id/opening-balance',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> delete(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/transactions/$id',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createBalanceAdjustment(
    String walletId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallets/$walletId/balance-adjustments',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateTransfer(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/transactions/$id/transfer',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createTransfer(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/transfers',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createVoucherCredit(
    String walletId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallets/$walletId/voucher-credits',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateVoucherCredit(
    String walletId,
    String creditId,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/wallets/$walletId/voucher-credits/$creditId',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createVoucherExpense(
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/voucher-expenses',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> updateVoucherExpense(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/voucher-expenses/$id',
      data: body,
    );
    return response.data!;
  }
}
