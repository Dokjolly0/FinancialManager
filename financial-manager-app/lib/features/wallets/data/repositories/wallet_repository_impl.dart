import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/voucher_lot.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_denomination.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../services/wallet_api.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl(this._api);

  final WalletApi _api;

  @override
  Future<List<Wallet>> listWallets() async {
    try {
      final raw = await _api.list();
      return raw
          .map((json) => Wallet.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Wallet> getWallet(String id) async {
    try {
      return Wallet.fromJson(await _api.get(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Wallet> createWallet(CreateWalletParams params) async {
    try {
      final response = await _api.create({
        'name': params.name,
        'type': params.type.toApi(),
        'icon': params.icon,
        'color': params.color,
        'opening_balance_minor': params.openingBalanceMinor,
        'voucher_unit_value_minor': params.voucherUnitValueMinor,
        'voucher_expiry_cutoff_month': params.voucherExpiryCutoffMonth,
        'voucher_expiry_month': params.voucherExpiryMonth,
        'voucher_expiry_day': params.voucherExpiryDay,
        'initial_voucher_quantity': params.initialVoucherQuantity,
        'voucher_loaded_at': params.voucherLoadedAt
            ?.toUtc()
            .toIso8601String(),
      });
      return Wallet.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Wallet> updateWallet(String id, UpdateWalletParams params) async {
    try {
      final response = await _api.update(id, {
        'name': params.name,
        'type': params.type.toApi(),
        'icon': params.icon,
        'color': params.color,
        'version': params.expectedVersion,
        'voucher_expiry_cutoff_month': params.voucherExpiryCutoffMonth,
        'voucher_expiry_month': params.voucherExpiryMonth,
        'voucher_expiry_day': params.voucherExpiryDay,
      });
      return Wallet.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Wallet> archiveWallet(
    String id, {
    required int expectedVersion,
  }) async {
    try {
      final response = await _api.archive(id, expectedVersion);
      return Wallet.fromJson(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<WalletDenomination>> getDenominations(String walletId) async {
    try {
      final raw = await _api.getDenominations(walletId);
      return raw
          .map(
            (json) => WalletDenomination.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<WalletDenomination>> replaceDenominations(
    String walletId,
    List<WalletDenomination> denominations,
  ) async {
    try {
      final raw = await _api.replaceDenominations(
        walletId,
        denominations.map((d) => d.toJson()).toList(),
      );
      return raw
          .map(
            (json) => WalletDenomination.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<List<VoucherLot>> getVoucherLots(String walletId) async {
    try {
      final raw = await _api.getVoucherLots(walletId);
      return raw
          .map((json) => VoucherLot.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
