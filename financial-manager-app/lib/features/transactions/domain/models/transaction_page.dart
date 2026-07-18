import 'ledger_transaction.dart';
import 'wallet.dart';

class TransactionPage {
  const TransactionPage({
    required this.transactions,
    this.nextCursor,
    required this.hasMore,
  });

  final List<LedgerTransaction> transactions;
  final String? nextCursor;
  final bool hasMore;
}

/// What create/update/delete return: the mutated transaction (null for
/// delete) alongside the wallet's new authoritative balance (plan.md
/// section 13.2: "La risposta deve includere ... transazione creata;
/// nuovo saldo"). The client never computes the new balance itself.
class TransactionWithWallet {
  const TransactionWithWallet({
    required this.transaction,
    required this.wallet,
  });

  final LedgerTransaction? transaction;
  final Wallet wallet;
}
