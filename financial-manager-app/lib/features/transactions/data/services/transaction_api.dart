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
    String? direction,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/transactions',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (direction != null) 'direction': direction,
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

  Future<Map<String, dynamic>> delete(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      '/transactions/$id',
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> createBalanceAdjustment(
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallet/balance-adjustments',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return response.data!;
  }
}
