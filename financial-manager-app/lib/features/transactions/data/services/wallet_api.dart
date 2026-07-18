import 'package:dio/dio.dart';

class WalletApi {
  WalletApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getWallet() async {
    final response = await _dio.get<Map<String, dynamic>>('/wallet');
    return response.data!;
  }
}
