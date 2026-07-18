import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped by any successful ledger mutation (create/update/delete a
/// transaction, balance adjustment) so screens showing wallet balance or
/// transaction lists (Home now; History/Reports later) know to refetch,
/// without the mutating feature needing to import and directly poke
/// each of those screens' controllers.
final ledgerRevisionProvider = StateProvider<int>((ref) => 0);

extension LedgerRevisionRef on Ref {
  void bumpLedgerRevision() => read(ledgerRevisionProvider.notifier).state++;
}
