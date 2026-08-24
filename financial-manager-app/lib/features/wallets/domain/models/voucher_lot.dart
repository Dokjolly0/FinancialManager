/// One batch of meal vouchers loaded onto a MEAL_VOUCHER wallet in one
/// operation (migration 0025's wallet_voucher_lots), all sharing one
/// [expiresAt] computed from the wallet's expiry policy. Consumed FIFO by
/// [expiresAt] — see [Wallet.voucherExpiryCutoffMonth] etc.
///
/// A lot is "active" while [quantityRemaining] > 0 and [expiresAt] hasn't
/// passed; "expiring soon" if active and [expiresAt] is within 30 days;
/// "expired" once [quantityExpired] > 0 (the backend writes this off
/// automatically, either lazily on the next mutation or by a scheduled
/// worker sweep — never by the user).
class VoucherLot {
  const VoucherLot({
    required this.id,
    required this.quantityTotal,
    required this.quantityRemaining,
    required this.quantityExpired,
    required this.expiresAt,
    required this.createdByTransactionId,
    this.expiredByTransactionId,
    required this.createdAt,
  });

  final String id;
  final int quantityTotal;
  final int quantityRemaining;
  final int quantityExpired;
  final DateTime expiresAt;
  final String createdByTransactionId;
  final String? expiredByTransactionId;
  final DateTime createdAt;

  bool get isActive => quantityRemaining > 0;
  bool get isExpiredHistory => quantityExpired > 0;

  bool isExpiringWithin(Duration window, {DateTime? now}) {
    if (!isActive) return false;
    final reference = now ?? DateTime.now();
    return !expiresAt.isAfter(reference.add(window));
  }

  static VoucherLot fromJson(Map<String, dynamic> json) {
    return VoucherLot(
      id: json['id'] as String,
      quantityTotal: json['quantity_total'] as int,
      quantityRemaining: json['quantity_remaining'] as int,
      quantityExpired: json['quantity_expired'] as int,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdByTransactionId: json['created_by_transaction_id'] as String,
      expiredByTransactionId: json['expired_by_transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 30-day lookahead used both here (client-side bucketing of a full lot
/// list) and by the backend's wallet-list "expiring soon" badge — kept in
/// sync manually since the value isn't returned by the API.
const Duration voucherExpiringSoonWindow = Duration(days: 30);
