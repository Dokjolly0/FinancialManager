import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper over `/v1/wallets*` (plan.md multi-wallet extension).
/// Returns raw decoded JSON; the repository maps it to domain models.
class WalletApi {
  WalletApi(this._dio, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Dio _dio;
  final Uuid _uuid;

  Future<List<dynamic>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/wallets');
    return response.data!['wallets'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/wallets/$id');
    return response.data!;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallets',
      data: body,
      options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
    );
    return (response.data!['wallet'] as Map<String, dynamic>?) ??
        response.data!;
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/wallets/$id',
      data: body,
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> archive(String id, int expectedVersion) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/wallets/$id/archive',
      data: {'version': expectedVersion},
    );
    return response.data!;
  }

  Future<List<dynamic>> getDenominations(String walletId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/wallets/$walletId/denominations',
    );
    return response.data!['denominations'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> replaceDenominations(
    String walletId,
    List<Map<String, dynamic>> denominations,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/wallets/$walletId/denominations',
      data: {'denominations': denominations},
    );
    return response.data!['denominations'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getVoucherLots(String walletId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/wallets/$walletId/voucher-lots',
    );
    return response.data!['voucher_lots'] as List<dynamic>? ?? [];
  }
}
