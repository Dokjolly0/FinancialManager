import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/account_repository.dart';
import 'account_providers.dart';

/// Saves edits from either the Profilo or Preferenze screen. Both submit
/// the same full PATCH /v1/me payload (plan.md section 14.2 replaces the
/// whole record), starting from the currently loaded [UserProfile] so
/// editing one screen's fields never clobbers the other's.
class ProfileController {
  ProfileController(this.ref);

  final Ref ref;

  Future<UserProfile> save(
    UserProfile current, {
    String? firstName,
    String? lastName,
    String? timezone,
    String? locale,
    String? theme,
    bool? balanceHiddenDefault,
    String? firstDayOfWeek,
  }) async {
    final updated = await ref
        .read(accountRepositoryProvider)
        .updateProfile(
          ProfileUpdate(
            firstName: firstName ?? current.firstName,
            lastName: lastName ?? current.lastName,
            timezone: timezone ?? current.timezone,
            locale: locale ?? current.locale,
            theme: theme ?? current.theme,
            balanceHiddenDefault:
                balanceHiddenDefault ?? current.balanceHiddenDefault,
            firstDayOfWeek: firstDayOfWeek ?? current.firstDayOfWeek,
            expectedVersion: current.version,
          ),
        );
    ref.invalidate(accountProfileProvider);
    return updated;
  }
}

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref);
});
