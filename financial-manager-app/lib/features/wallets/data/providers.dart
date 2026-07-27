import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/models/wallet.dart';
import '../domain/repositories/wallet_repository.dart';
import 'repositories/wallet_repository_impl.dart';
import 'services/wallet_api.dart';

final walletApiProvider = Provider<WalletApi>((ref) {
  return WalletApi(ref.watch(apiClientProvider).dio);
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(ref.watch(walletApiProvider));
});

/// Cached list of every active wallet the user owns, shared by Home's
/// per-wallet list, the wallet picker, the transfer sheet, and the reports
/// wallet selector. Must be registered in user_scoped_providers.dart (this
/// project's checklist for every per-account provider) since it isn't
/// .autoDispose. Callers that mutate a wallet (create/update/archive) or
/// the ledger (transaction/balance-adjustment/transfer) call
/// `ref.invalidate(walletsListProvider)` to refetch.
final walletsListProvider = FutureProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).listWallets();
});
