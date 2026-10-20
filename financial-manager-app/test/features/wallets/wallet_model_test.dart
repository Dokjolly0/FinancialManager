import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/wallets/domain/models/wallet.dart';
import 'package:financialmanager/features/wallets/domain/models/wallet_type.dart';

Map<String, dynamic> _walletJson({Object? purpose}) => {
  'id': 'w1',
  'name': 'Conto spese',
  'currency': 'EUR',
  'current_balance_minor': 12345,
  'type': 'BANK',
  'icon': 'bank',
  'color': '#6750A4',
  'version': 2,
  'updated_at': '2026-10-20T08:00:00Z',
  'purpose': purpose,
};

void main() {
  test('Wallet.fromJson reads the purpose', () {
    final wallet = Wallet.fromJson(_walletJson(purpose: 'Spese quotidiane'));
    expect(wallet.type, WalletType.bank);
    expect(wallet.purpose, 'Spese quotidiane');
  });

  test('Wallet.fromJson treats a null or missing purpose as unset', () {
    expect(Wallet.fromJson(_walletJson()).purpose, isNull);
    expect(Wallet.fromJson(_walletJson()..remove('purpose')).purpose, isNull);
  });
}
