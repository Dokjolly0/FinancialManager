import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/user_profile.dart';
import '../view_models/account_providers.dart';
import '../view_models/profile_controller.dart';

/// Preferences (plan.md section 7.13): theme, timezone, language, balance
/// visibility on open, first day of the week.
class AccountPreferencesScreen extends ConsumerStatefulWidget {
  const AccountPreferencesScreen({super.key});

  @override
  ConsumerState<AccountPreferencesScreen> createState() =>
      _AccountPreferencesScreenState();
}

class _AccountPreferencesScreenState
    extends ConsumerState<AccountPreferencesScreen> {
  static const _timezones = [
    'Europe/Rome',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Asia/Tokyo',
    'UTC',
  ];

  static const _locales = [
    ('it-IT', 'Italiano'),
    ('en-US', 'English'),
  ];

  // PATCH /v1/me uses optimistic locking (version) and replaces the whole
  // record. Two edits fired back-to-back (e.g. tapping theme then first-day
  // before the first save's response — and the version bump it carries —
  // comes back) would both read the same stale version and the second
  // would 409 (found live: rapidly tapping three preferences in a row).
  // Serializing saves through this flag is simpler than debouncing/queuing
  // since these are infrequent settings, not something users batch-edit.
  bool _isSaving = false;

  Future<void> _update(
    UserProfile profile, {
    String? theme,
    String? timezone,
    String? locale,
    bool? balanceHiddenDefault,
    String? firstDayOfWeek,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileControllerProvider)
          .save(
            profile,
            theme: theme,
            timezone: timezone,
            locale: locale,
            balanceHiddenDefault: balanceHiddenDefault,
            firstDayOfWeek: firstDayOfWeek,
          );
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              presentError(e, AppLocalizations.of(context)).message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(accountProfileProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountPreferencesMenuTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineError(
          message: l10n.accountPreferencesLoadError,
          onRetry: () => ref.invalidate(accountProfileProvider),
        ),
        data: (profile) => AbsorbPointer(
          absorbing: _isSaving,
          child: Opacity(
            opacity: _isSaving ? 0.6 : 1,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(l10n.themeLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system', label: Text(l10n.themeOptionSystem)),
                    ButtonSegment(value: 'light', label: Text(l10n.themeOptionLight)),
                    ButtonSegment(value: 'dark', label: Text(l10n.themeOptionDark)),
                  ],
                  selected: {profile.theme},
                  onSelectionChanged: (s) =>
                      _update(profile, theme: s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.firstDayOfWeekLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'monday', label: Text(l10n.weekdayMonday)),
                    ButtonSegment(value: 'sunday', label: Text(l10n.weekdaySunday)),
                  ],
                  selected: {profile.firstDayOfWeek},
                  onSelectionChanged: (s) =>
                      _update(profile, firstDayOfWeek: s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.hideBalanceOnOpenTitle),
                  subtitle: Text(l10n.hideBalanceOnOpenSubtitle),
                  value: profile.balanceHiddenDefault,
                  onChanged: (v) => _update(profile, balanceHiddenDefault: v),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.timezoneLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  // Rebuilding with a fresh key whenever the saved version
                  // changes forces this field to resync its displayed value
                  // from `profile` — DropdownButtonFormField otherwise only
                  // reads `initialValue` once, on first creation.
                  key: ValueKey('timezone-${profile.version}'),
                  initialValue: _timezones.contains(profile.timezone)
                      ? profile.timezone
                      : _timezones.first,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final tz in _timezones)
                      DropdownMenuItem(value: tz, child: Text(tz)),
                  ],
                  onChanged: (v) {
                    if (v != null) _update(profile, timezone: v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.languageLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  key: ValueKey('locale-${profile.version}'),
                  initialValue: _locales.any((l) => l.$1 == profile.locale)
                      ? profile.locale
                      : _locales.first.$1,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final locale in _locales)
                      DropdownMenuItem(value: locale.$1, child: Text(locale.$2)),
                  ],
                  onChanged: (v) {
                    if (v != null) _update(profile, locale: v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
