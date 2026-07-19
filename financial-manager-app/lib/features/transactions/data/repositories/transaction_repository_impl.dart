import 'package:dio/dio.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/transaction_page.dart';
import '../../domain/models/wallet.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../services/transaction_api.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._api);

  final TransactionApi _api;

  TransactionWithWallet _parseWithWallet(Map<String, dynamic> json) {
    final rawTransaction = json['transaction'] as Map<String, dynamic>?;
    return TransactionWithWallet(
      transaction: rawTransaction == null
          ? null
          : LedgerTransaction.fromJson(rawTransaction),
      wallet: Wallet.fromJson(json['wallet'] as Map<String, dynamic>),
    );
  }

  @override
  Future<TransactionWithWallet> createStandard(
    CreateTransactionParams params,
  ) async {
    try {
      final response = await _api.create({
        'direction': params.direction.toApi(),
        'amount_minor': params.amountMinor,
        'currency': params.currency,
        'title': params.title,
        'description': params.description,
        'category_id': params.categoryId,
        'template_id': params.templateId,
        'media_id': params.mediaId,
        'occurred_at': params.occurredAt.toUtc().toIso8601String(),
      });
      return _parseWithWallet(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<LedgerTransaction> getTransaction(String id) async {
    try {
      return LedgerTransaction.fromJson(await _api.get(id));
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  /// Maps the "tutte/uscite/entrate/rettifiche" type filter (plan.md
  /// section 7.9) onto the backend's direction/kind query params. Standard
  /// transactions are filtered by direction; adjustments are a kind
  /// regardless of direction; "all" leaves both unset so OPENING_BALANCE
  /// and BALANCE_ADJUSTMENT rows still show up with their own tile style.
  (String?, String?) _directionAndKindFor(TransactionTypeFilter type) {
    return switch (type) {
      TransactionTypeFilter.all => (null, null),
      TransactionTypeFilter.debit => ('DEBIT', 'STANDARD'),
      TransactionTypeFilter.credit => ('CREDIT', 'STANDARD'),
      TransactionTypeFilter.adjustments => (null, 'BALANCE_ADJUSTMENT'),
    };
  }

  @override
  Future<TransactionPage> listTransactions({
    String? cursor,
    int limit = 20,
    TransactionListFilter filter = const TransactionListFilter(),
  }) async {
    try {
      final (direction, kind) = _directionAndKindFor(filter.type);
      final response = await _api.list(
        cursor: cursor,
        limit: limit,
        direction: direction,
        kind: kind,
        categoryId: filter.categoryId,
        title: filter.title,
        amountMinMinor: filter.amountMinMinor,
        amountMaxMinor: filter.amountMaxMinor,
        occurredFrom: filter.occurredFrom,
        occurredTo: filter.occurredTo,
      );
      final rawTransactions = response['transactions'] as List<dynamic>? ?? [];
      return TransactionPage(
        transactions: rawTransactions
            .map(
              (raw) => LedgerTransaction.fromJson(raw as Map<String, dynamic>),
            )
            .toList(),
        nextCursor: response['next_cursor'] as String?,
        hasMore: response['has_more'] as bool? ?? false,
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<TransactionWithWallet> updateStandard(
    String id,
    UpdateTransactionParams params,
  ) async {
    try {
      final response = await _api.update(id, {
        'direction': params.direction.toApi(),
        'amount_minor': params.amountMinor,
        'title': params.title,
        'description': params.description,
        'category_id': params.categoryId,
        'template_id': params.templateId,
        'media_id': params.mediaId,
        'occurred_at': params.occurredAt.toUtc().toIso8601String(),
        'version': params.expectedVersion,
      });
      return _parseWithWallet(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<Wallet> deleteTransaction(String id) async {
    try {
      final response = await _api.delete(id);
      return Wallet.fromJson(response['wallet'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }

  @override
  Future<TransactionWithWallet> createBalanceAdjustment({
    required int targetBalanceMinor,
    String? reason,
  }) async {
    try {
      final response = await _api.createBalanceAdjustment({
        'target_balance_minor': targetBalanceMinor,
        'reason': reason,
      });
      return _parseWithWallet(response);
    } on DioException catch (e) {
      throw ErrorMapper.fromException(e);
    }
  }
}
