import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_settings.dart';
import '../view_models/ai_provider_form.dart';
import '../widgets/ai_provider_labels.dart';

/// Provider, API key and model (plan.md section 32.7). The key is never
/// shown back: a stored key appears as its hint and can be replaced.
class AiProviderSettingsScreen extends ConsumerWidget {
  const AiProviderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settingsAsync = ref.watch(aiSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiProviderMenuTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: InlineError(
            message: error is AppError
                ? presentError(error, l10n).message
                : l10n.errorCodeUnknownError,
            onRetry: () => ref.invalidate(aiSettingsProvider),
          ),
        ),
        data: (settings) => _ProviderForm(settings: settings),
      ),
    );
  }
}

class _ProviderForm extends ConsumerStatefulWidget {
  const _ProviderForm({required this.settings});

  final AiSettings settings;

  @override
  ConsumerState<_ProviderForm> createState() => _ProviderFormState();
}

class _ProviderFormState extends ConsumerState<_ProviderForm> {
  late AiProviderKind _provider;
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  final _modelFocus = FocusNode();
  final _maxTokens = TextEditingController();
  final _inputPrice = TextEditingController();
  final _outputPrice = TextEditingController();
  bool _includeTransactions = false;
  bool _anonymizeTitles = false;
  bool _replacingKey = false;
  bool _removeKey = false;
  bool _obscureKey = true;

  List<AiModelInfo> _models = const [];
  bool _loadingModels = false;
  bool _testing = false;
  AiTestResult? _testResult;
  String? _probeError;

  bool _saving = false;
  Map<String, String> _fieldErrors = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _provider = s.active?.provider ?? AiProviderKind.anthropic;
    _baseUrl.text = s.active?.baseUrl ?? '';
    _model.text = s.active?.model ?? '';
    _maxTokens.text = '${s.maxOutputTokens}';
    _inputPrice.text = s.inputPricePerMTok?.toString() ?? '';
    _outputPrice.text = s.outputPricePerMTok?.toString() ?? '';
    _includeTransactions = s.defaultIncludeTransactions;
    _anonymizeTitles = s.defaultAnonymizeTitles;
  }

  @override
  void dispose() {
    for (final c in [
      _baseUrl,
      _apiKey,
      _model,
      _maxTokens,
      _inputPrice,
      _outputPrice,
    ]) {
      c.dispose();
    }
    _modelFocus.dispose();
    super.dispose();
  }

  /// The credential already saved for the provider/base URL in the form.
  AiCredential? get _stored => widget.settings.credentialFor(
    _provider,
    baseUrl: _baseUrl.text.trim().replaceAll(RegExp(r'/+$'), ''),
  );

  AiProviderFormValues get _values => AiProviderFormValues(
    provider: _provider,
    baseUrl: _baseUrl.text,
    apiKeyInput: _apiKey.text,
    removeStoredKey: _removeKey,
    model: _model.text,
    maxOutputTokens: int.tryParse(_maxTokens.text.trim()) ?? 0,
    inputPrice: parseAiPrice(_inputPrice.text),
    outputPrice: parseAiPrice(_outputPrice.text),
    includeTransactions: _includeTransactions,
    anonymizeTitles: _anonymizeTitles,
  );

  void _selectProvider(AiProviderKind kind) {
    setState(() {
      _provider = kind;
      final stored = widget.settings.credentialFor(kind);
      _baseUrl.text = stored?.baseUrl ?? '';
      _model.text = stored?.model ?? '';
      _apiKey.clear();
      _replacingKey = false;
      _removeKey = false;
      _models = const [];
      _testResult = null;
      _probeError = null;
      _fieldErrors = const {};
    });
  }

  Future<void> _loadModels() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loadingModels = true;
      _probeError = null;
    });
    try {
      final models = await ref
          .read(aiRepositoryProvider)
          .listModels(aiProbeFromForm(_values));
      setState(() => _models = models);
      if (mounted && models.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.aiModelsNoneFound)));
      }
    } on AppError catch (e) {
      setState(() => _probeError = _describe(e, l10n));
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _testing = true;
      _testResult = null;
      _probeError = null;
    });
    try {
      final result = await ref
          .read(aiRepositoryProvider)
          .testConnection(aiProbeFromForm(_values));
      setState(() => _testResult = result);
    } on AppError catch (e) {
      setState(() => _probeError = _describe(e, l10n));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// Localized message plus the provider's own explanation, which often
  /// says exactly what is wrong ("model 'x' does not exist").
  String _describe(AppError e, AppLocalizations l10n) {
    final message = presentError(e, l10n).message;
    if (e is DomainError &&
        e.code.startsWith('AI_PROVIDER_') &&
        e.message.isNotEmpty) {
      return '$message\n${e.message}';
    }
    return message;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final values = _values;
    final errors = validateAiProviderForm(values, stored: _stored);
    if (errors.isNotEmpty) {
      setState(() => _fieldErrors = errors);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref
          .read(aiRepositoryProvider)
          .saveSettings(
            buildSaveAiSettingsParams(
              values,
              expectedVersion: widget.settings.version,
            ),
          );
      ref.invalidate(aiSettingsProvider);
      if (mounted) context.pop();
    } on AppError catch (e) {
      final p = presentError(e, l10n);
      setState(() {
        _saving = false;
        _error = p.message;
        _fieldErrors = e is DomainError ? e.fieldErrors : const {};
      });
    }
  }

  Future<void> _forgetProvider(AiCredential stored) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.aiForgetProviderTitle,
      message: l10n.aiForgetProviderMessage,
      confirmLabel: l10n.aiForgetProviderAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(aiRepositoryProvider).deleteCredential(stored.id);
      ref.invalidate(aiSettingsProvider);
      if (mounted) context.pop();
    } on AppError catch (e) {
      setState(() => _error = presentError(e, l10n).message);
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

    final stored = _stored;
    final showStoredKey =
        stored?.hasKey == true && !_replacingKey && !_removeKey;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        DropdownButtonFormField<AiProviderKind>(
          initialValue: _provider,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.aiProviderLabel),
          items: [
            for (final kind in AiProviderKind.cloud)
              DropdownMenuItem(
                value: kind,
                child: Text(
                  aiProviderLabel(l10n, kind),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (kind) => kind == null ? null : _selectProvider(kind),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(switch (_provider) {
          AiProviderKind.anthropic => l10n.aiProviderHintAnthropic,
          AiProviderKind.openai => l10n.aiProviderHintOpenai,
          AiProviderKind.gemini => l10n.aiProviderHintGemini,
          AiProviderKind.openaiCompatible => l10n.aiProviderHintCompatible,
          AiProviderKind.onDevice => '',
        }, style: theme.textTheme.bodySmall),
        if (_provider.requiresBaseUrl) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _baseUrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.aiBaseUrlLabel,
              hintText: 'https://api.example.com/v1',
              helperText: l10n.aiBaseUrlHelper,
              helperMaxLines: 3,
              errorText: fieldError('base_url'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final p in aiCompatiblePresets)
                ActionChip(
                  label: Text(p.name),
                  onPressed: () => setState(() {
                    _baseUrl.text = p.baseUrl;
                    _models = const [];
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (showStoredKey)
          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.aiApiKeyLabel,
              errorText: fieldError('api_key'),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l10n.aiApiKeyStored(stored!.keyHint ?? '…')),
                ),
                TextButton(
                  onPressed: () => setState(() => _replacingKey = true),
                  child: Text(l10n.aiApiKeyReplace),
                ),
                if (!_provider.requiresApiKey)
                  TextButton(
                    onPressed: () => setState(() => _removeKey = true),
                    child: Text(l10n.aiApiKeyRemove),
                  ),
              ],
            ),
          )
        else
          TextField(
            controller: _apiKey,
            obscureText: _obscureKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: _provider.requiresApiKey
                  ? l10n.aiApiKeyLabel
                  : l10n.aiApiKeyOptionalLabel,
              helperText: _removeKey
                  ? l10n.aiApiKeyWillBeRemoved
                  : l10n.aiApiKeyHelper,
              helperMaxLines: 3,
              errorText: fieldError('api_key'),
              suffixIcon: IconButton(
                tooltip: _obscureKey ? l10n.aiApiKeyShow : l10n.aiApiKeyHide,
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RawAutocomplete<String>(
                textEditingController: _model,
                focusNode: _modelFocus,
                optionsBuilder: (value) {
                  final q = value.text.toLowerCase();
                  return _models
                      .map((m) => m.id)
                      .where((id) => q.isEmpty || id.toLowerCase().contains(q))
                      .take(50);
                },
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 280,
                        maxWidth: 360,
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final id in options)
                            ListTile(
                              dense: true,
                              title: Text(id),
                              onTap: () => onSelected(id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: l10n.aiModelLabel,
                          helperText: _models.isEmpty
                              ? l10n.aiModelHelper
                              : l10n.aiModelsLoaded(_models.length),
                          helperMaxLines: 2,
                          errorText: fieldError('model'),
                        ),
                      );
                    },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: OutlinedButton(
                onPressed: _loadingModels ? null : _loadModels,
                child: _loadingModels
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.aiLoadModels),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.network_check),
          label: Text(l10n.aiTestConnection),
        ),
        if (_testResult != null || _probeError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _TestResultBanner(result: _testResult, error: _probeError),
        ] else if (stored?.lastTestedAt != null && !_replacingKey) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            stored!.lastTestOk == true
                ? l10n.aiLastTestOk
                : l10n.aiLastTestFailed,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l10n.aiAdvancedSettings),
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
          children: [
            TextField(
              controller: _maxTokens,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.aiMaxOutputTokensLabel,
                helperText: l10n.aiMaxOutputTokensHelper(
                  aiMinOutputTokens,
                  aiMaxOutputTokens,
                ),
                helperMaxLines: 2,
                errorText: fieldError('max_output_tokens'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.aiPricesTitle, style: theme.textTheme.titleSmall),
            Text(l10n.aiPricesHelper, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.aiInputPriceLabel,
                      errorText: fieldError('input_price_per_mtok'),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _outputPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.aiOutputPriceLabel,
                      errorText: fieldError('output_price_per_mtok'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.aiDefaultIncludeTransactions),
              subtitle: Text(l10n.aiDefaultIncludeTransactionsHint),
              value: _includeTransactions,
              onChanged: (v) => setState(() => _includeTransactions = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.aiDefaultAnonymizeTitles),
              subtitle: Text(l10n.aiDefaultAnonymizeTitlesHint),
              value: _anonymizeTitles,
              onChanged: (v) => setState(() => _anonymizeTitles = v),
            ),
          ],
        ),
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
              : Text(l10n.aiSaveSettings),
        ),
        if (stored != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _saving ? null : () => _forgetProvider(stored),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.aiForgetProviderAction),
          ),
        ],
      ],
    );
  }
}

class _TestResultBanner extends StatelessWidget {
  const _TestResultBanner({this.result, this.error});

  final AiTestResult? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ok = result?.ok == true;
    String text;
    if (error != null) {
      text = error!;
    } else if (ok) {
      text = result!.model == null
          ? l10n.aiTestOkKeyOnly(result!.latency.inMilliseconds)
          : l10n.aiTestOk(result!.model!, result!.latency.inMilliseconds);
    } else {
      final localized = result?.errorCode == null
          ? l10n.errorCodeUnknownError
          : localizeErrorCode(l10n, result!.errorCode!);
      text = result?.errorMessage == null || result!.errorMessage!.isEmpty
          ? localized
          : '$localized\n${result!.errorMessage}';
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
