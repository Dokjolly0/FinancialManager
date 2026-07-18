import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../services/wallet_api.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._api);

  final WalletApi _api;

  @override
  Future<Wallet> getWallet() async {
    try {
      return Wallet.fromJson(await _api.getWallet());
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
