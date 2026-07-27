import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/repositories/transaction_repository.dart';
import 'repositories/transaction_repository_impl.dart';
import 'services/transaction_api.dart';

final transactionApiProvider = Provider<TransactionApi>((ref) {
  return TransactionApi(ref.watch(apiClientProvider).dio);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepositoryImpl(ref.watch(transactionApiProvider));
});
