import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/account/domain/models/account_session.dart';
import 'package:financialmanager/features/account/domain/models/export_record.dart';
import 'package:financialmanager/features/account/domain/models/linked_identity.dart';
import 'package:financialmanager/features/account/domain/models/user_profile.dart';

void main() {
  test('UserProfile.fromJson parses the backend shape', () {
    final profile = UserProfile.fromJson({
      'id': 'u1',
      'first_name': 'Sara',
      'last_name': 'Bianchi',
      'username': 'sarab',
      'email': 'sara@example.com',
      'email_verified': true,
      'avatar_mode': 'generated',
      'avatar_background_color': '#336699',
      'avatar_text_color': '#FFFFFF',
      'locale': 'it-IT',
      'timezone': 'Europe/Rome',
      'theme': 'system',
      'balance_hidden_default': false,
      'first_day_of_week': 'monday',
      'version': 3,
      'created_at': '2026-07-18T12:00:00Z',
    });
    expect(profile.firstName, 'Sara');
    expect(profile.emailVerified, isTrue);
    expect(profile.avatarMediaId, isNull);
    expect(profile.firstDayOfWeek, 'monday');
    expect(profile.version, 3);
  });

  test('AccountSession.fromJson parses the backend shape', () {
    final session = AccountSession.fromJson({
      'id': 's1',
      'device_name': 'Pixel 8',
      'platform': 'ANDROID',
      'created_at': '2026-07-01T10:00:00Z',
      'last_used_at': '2026-07-18T10:00:00Z',
      'expires_at': '2026-08-01T10:00:00Z',
      'is_current': true,
    });
    expect(session.deviceName, 'Pixel 8');
    expect(session.isCurrent, isTrue);
  });

  test('LinkedIdentity.fromJson handles a null last_used_at', () {
    final identity = LinkedIdentity.fromJson({
      'provider': 'google',
      'linked_at': '2026-07-01T10:00:00Z',
    });
    expect(identity.provider, 'google');
    expect(identity.lastUsedAt, isNull);
  });

  test('ExportRecord.fromJson exposes isReady/isFailed correctly', () {
    final ready = ExportRecord.fromJson({
      'id': 'e1',
      'format': 'csv',
      'status': 'ready',
      'download_url': '/v1/me/export/e1/download',
      'created_at': '2026-07-18T10:00:00Z',
    });
    expect(ready.isReady, isTrue);
    expect(ready.isFailed, isFalse);

    final failed = ExportRecord.fromJson({
      'id': 'e2',
      'format': 'json',
      'status': 'failed',
      'error_message': 'boom',
      'created_at': '2026-07-18T10:00:00Z',
    });
    expect(failed.isReady, isFalse);
    expect(failed.isFailed, isTrue);
    expect(failed.errorMessage, 'boom');
  });
}
