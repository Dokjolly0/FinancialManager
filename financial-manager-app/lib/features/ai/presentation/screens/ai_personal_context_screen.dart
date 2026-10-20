import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_user_context.dart';

/// "Contesto personale" (plan.md section 32.3): what the model should know
/// to personalize the report. Everything is optional.
class AiPersonalContextScreen extends ConsumerWidget {
  const AiPersonalContextScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contextAsync = ref.watch(aiUserContextProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiContextMenuTitle)),
      body: contextAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: error is AppError
                ? presentError(error, l10n).message
                : l10n.errorCodeUnknownError,
            onRetry: () => ref.invalidate(aiUserContextProvider),
          ),
        ),
        data: (ctx) => _ContextForm(initial: ctx),
      ),
    );
  }
}

String aiIncomeTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'EMPLOYEE' => l10n.aiIncomeEmployee,
  'SELF_EMPLOYED' => l10n.aiIncomeSelfEmployed,
  'STUDENT' => l10n.aiIncomeStudent,
  'RETIRED' => l10n.aiIncomeRetired,
  'UNEMPLOYED' => l10n.aiIncomeUnemployed,
  'MIXED' => l10n.aiIncomeMixed,
  _ => l10n.aiIncomeOther,
};

class _ContextForm extends ConsumerStatefulWidget {
  const _ContextForm({required this.initial});

  final AiUserContext initial;

  @override
  ConsumerState<_ContextForm> createState() => _ContextFormState();
}

class _ContextFormState extends ConsumerState<_ContextForm> {
  int? _household;
  String? _incomeType;
  String? _style;
  late final TextEditingController _aboutMe;
  late final TextEditingController _goals;
  late final TextEditingController _ignore;
  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _household = c.householdSize;
    _incomeType = c.incomeType;
    _style = c.responseStyle;
    _aboutMe = TextEditingController(text: c.aboutMe ?? '');
    _goals = TextEditingController(text: c.goals ?? '');
    _ignore = TextEditingController(text: c.ignoreNotes ?? '');
  }

  @override
  void dispose() {
    _aboutMe.dispose();
    _goals.dispose();
    _ignore.dispose();
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref
          .read(aiRepositoryProvider)
          .saveUserContext(
            AiUserContext(
              householdSize: _household,
              incomeType: _incomeType,
              aboutMe: _text(_aboutMe),
              goals: _text(_goals),
              ignoreNotes: _text(_ignore),
              responseStyle: _style,
              version: widget.initial.version,
            ),
          );
      ref.invalidate(aiUserContextProvider);
      ref.invalidate(aiSettingsProvider);
      if (mounted) context.pop();
    } on AppError catch (e) {
      setState(() {
        _saving = false;
        _error = presentError(e, l10n).message;
        _fieldErrors = e is DomainError ? e.fieldErrors : const {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String? fieldError(String key) {
      final code = _fieldErrors[key];
      return code == null ? null : localizeErrorCode(l10n, code);
    }

    Widget textField(
      TextEditingController c,
      String label,
      String hint,
      String field,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: c,
        minLines: 2,
        maxLines: 6,
        maxLength: aiContextTextMaxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintMaxLines: 3,
          alignLabelWithHint: true,
          errorText: fieldError(field),
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(l10n.aiContextIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiHouseholdLabel),
          subtitle: Text(
            _household == null
                ? l10n.aiNotSpecified
                : l10n.aiHouseholdValue(_household!),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.aiHouseholdLess,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _household == null
                    ? null
                    : () => setState(
                        () => _household = _household! <= 1
                            ? null
                            : _household! - 1,
                      ),
              ),
              IconButton(
                tooltip: l10n.aiHouseholdMore,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: (_household ?? 0) >= 20
                    ? null
                    : () => setState(() => _household = (_household ?? 0) + 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String?>(
          initialValue: _incomeType,
          decoration: InputDecoration(
            labelText: l10n.aiIncomeTypeLabel,
            errorText: fieldError('income_type'),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.aiNotSpecified)),
            for (final t in aiIncomeTypes)
              DropdownMenuItem(
                value: t,
                child: Text(aiIncomeTypeLabel(l10n, t)),
              ),
          ],
          onChanged: (v) => setState(() => _incomeType = v),
        ),
        const SizedBox(height: AppSpacing.md),
        textField(
          _aboutMe,
          l10n.aiAboutMeLabel,
          l10n.aiAboutMeHint,
          'about_me',
        ),
        textField(_goals, l10n.aiGoalsLabel, l10n.aiGoalsHint, 'goals'),
        textField(
          _ignore,
          l10n.aiIgnoreLabel,
          l10n.aiIgnoreHint,
          'ignore_notes',
        ),
        Text(l10n.aiResponseStyleLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<String?>(
          segments: [
            ButtonSegment(value: null, label: Text(l10n.aiStyleDefault)),
            ButtonSegment(value: 'CONCISE', label: Text(l10n.aiStyleConcise)),
            ButtonSegment(value: 'DETAILED', label: Text(l10n.aiStyleDetailed)),
          ],
          selected: {_style},
          onSelectionChanged: (s) => setState(() => _style = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.aiContextPrivacyNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.aiSaveContext),
        ),
      ],
    );
  }
}
