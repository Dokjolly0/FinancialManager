import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/local/model_downloader.dart';
import '../../data/local/model_importer.dart';
import '../../data/providers.dart';
import '../../domain/models/device_capabilities.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';
import '../../domain/models/local_model_record.dart';
import '../view_models/local_models_controller.dart';
import '../widgets/local_model_labels.dart';

/// Assistente AI → Modelli sul dispositivo (plan.md section 33): the
/// catalog by engine, downloads, imports and the installed models.
class AiLocalModelsScreen extends ConsumerStatefulWidget {
  const AiLocalModelsScreen({super.key});

  @override
  ConsumerState<AiLocalModelsScreen> createState() =>
      _AiLocalModelsScreenState();
}

class _AiLocalModelsScreenState extends ConsumerState<AiLocalModelsScreen> {
  /// The picker copies the chosen file into the app's cache first, which
  /// takes a while for a model.
  bool _picking = false;

  LocalModelsController get _controller =>
      ref.read(localModelsControllerProvider.notifier);

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _errorText(Object e) {
    final l10n = AppLocalizations.of(context);
    return e is ModelDownloadException
        ? localizeErrorCode(l10n, e.code)
        : l10n.errorCodeUnknownError;
  }

  Future<void> _download(LocalModelSpec spec, RamFit fit) async {
    final l10n = AppLocalizations.of(context);
    if (fit == RamFit.insufficient) {
      final go = await ConfirmationSheet.show(
        context,
        title: l10n.aiLocalRamWarningTitle,
        message: l10n.aiLocalRamWarningMessage,
        confirmLabel: l10n.aiLocalDownloadAnyway,
      );
      if (!go || !mounted) return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _LicenseDialog(spec: spec),
    );
    if (accepted != true) return;
    _controller.download(spec.id);
  }

  Future<void> _delete(LocalModelRecord record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.aiLocalDeleteTitle,
      message: l10n.aiLocalDeleteMessage(record.label),
      confirmLabel: l10n.aiDeleteAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    final freed = await _controller.delete(record.id);
    if (mounted) _snack(l10n.aiLocalDeleted(formatModelBytes(context, freed)));
  }

  Future<void> _importFile() async {
    final l10n = AppLocalizations.of(context);
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        onFileLoading: (status) {
          if (mounted) {
            setState(() => _picking = status == FilePickerStatus.picking);
          }
        },
      );
    } catch (_) {
      _snack(l10n.errorCodeUnknownError);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    final path = picked?.path;
    if (picked == null || path == null || !mounted) return;
    final meta = await showDialog<_ImportDetails>(
      context: context,
      builder: (_) => _ImportDialog(fileName: picked!.name, askUrl: false),
    );
    if (meta == null) {
      await FilePicker.clearTemporaryFiles();
      return;
    }
    try {
      final record = await _controller.importFile(
        File(path),
        meta.metadata,
        sha256: meta.sha256,
      );
      if (ref.read(localModelsControllerProvider).activeModelId == null) {
        await _controller.setActive(record.id);
      }
      _snack(
        record.verified
            ? l10n.aiLocalImported(record.label)
            : l10n.aiLocalImportedUnverified(record.label),
      );
    } catch (e) {
      _snack(_errorText(e));
    } finally {
      await FilePicker.clearTemporaryFiles();
    }
  }

  Future<void> _importUrl() async {
    final meta = await showDialog<_ImportDetails>(
      context: context,
      builder: (_) => const _ImportDialog(askUrl: true),
    );
    if (meta == null) return;
    try {
      await _controller.importUrl(
        meta.url!,
        meta.metadata,
        sha256: meta.sha256,
      );
    } catch (e) {
      _snack(_errorText(e));
    }
  }

  Future<void> _editToken() async {
    final l10n = AppLocalizations.of(context);
    final store = ref.read(huggingFaceTokenStoreProvider);
    final current = await store.read();
    if (!mounted) return;
    final token = await showDialog<String>(
      context: context,
      builder: (_) => _TokenDialog(hasToken: current != null),
    );
    if (token == null) return;
    await store.write(token);
    _snack(token.isEmpty ? l10n.aiLocalTokenRemoved : l10n.aiLocalTokenSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(localModelsControllerProvider);
    final theme = Theme.of(context);
    // Whatever made a model active (a pick, the first download, a delete),
    // the server's label follows.
    ref.listen(localModelsControllerProvider.select((s) => s.activeModelId), (
      _,
      id,
    ) {
      final s = ref.read(localModelsControllerProvider);
      syncLocalModelLabel(ref, id == null ? null : s.installedById(id)?.label);
    });

    final Widget body;
    if (state.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.loadError != null || state.catalog == null) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: InlineError(
          message: l10n.errorCodeUnknownError,
          onRetry: () => ref.invalidate(localModelsControllerProvider),
        ),
      );
    } else {
      final catalog = state.catalog!;
      final urlTasks = state.tasks.values.where((t) => t.urlImport != null);
      body = RefreshIndicator(
        onRefresh: _controller.refreshCapabilities,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            _DeviceCard(state: state),
            if (_picking || state.importProgress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _picking ? l10n.aiLocalPickingFile : l10n.aiLocalImporting,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: _picking ? null : state.importProgress,
              ),
            ],
            if (state.installed.isNotEmpty) ...[
              _SectionTitle(l10n.aiLocalInstalledTitle),
              Card(
                child: Column(
                  children: [
                    for (final r in state.installed)
                      _InstalledTile(
                        record: r,
                        active: r.id == state.activeModelId,
                        onUse: () => _controller.setActive(r.id),
                        onDelete: () => _delete(r),
                      ),
                  ],
                ),
              ),
            ],
            for (final t in urlTasks) ...[
              const SizedBox(height: AppSpacing.sm),
              _UrlTaskCard(
                task: t,
                onPause: () => _controller.pause(t.id),
                onResume: () => _controller.resume(t.id),
                onCancel: () => _controller.cancel(t.id),
              ),
            ],
            for (final engine in LocalEngineKind.values) ...[
              if (catalog.models.any(
                (m) => m.engine == engine && state.installedById(m.id) == null,
              )) ...[
                _SectionTitle(
                  engine == LocalEngineKind.litertLm
                      ? l10n.aiLocalEngineLitert
                      : l10n.aiLocalEngineLlama,
                  subtitle: engine == LocalEngineKind.litertLm
                      ? l10n.aiLocalEngineLitertHint
                      : l10n.aiLocalEngineLlamaHint,
                ),
                for (final spec in catalog.models.where(
                  (m) =>
                      m.engine == engine && state.installedById(m.id) == null,
                ))
                  _CatalogCard(
                    spec: spec,
                    task: state.tasks[spec.id],
                    fit: state.ramFit(spec),
                    onDownload: () => _download(spec, state.ramFit(spec)),
                    onPause: () => _controller.pause(spec.id),
                    onResume: () => _controller.resume(spec.id),
                    onCancel: () => _controller.cancel(spec.id),
                  ),
              ],
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiLocalModelsTitle),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) => switch (action) {
              'file' => _importFile(),
              'url' => _importUrl(),
              _ => _editToken(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'file',
                enabled: !_picking && state.importProgress == null,
                child: Text(l10n.aiLocalImportFile),
              ),
              PopupMenuItem(value: 'url', child: Text(l10n.aiLocalImportUrl)),
              PopupMenuItem(
                value: 'token',
                child: Text(l10n.aiLocalTokenAction),
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// RAM, free space and the Wi-Fi rule.
class _DeviceCard extends ConsumerWidget {
  const _DeviceCard({required this.state});

  final LocalModelsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final caps = state.capabilities;
    final facts = [
      if (caps?.totalMemBytes != null)
        l10n.aiLocalDeviceRam(formatModelBytes(context, caps!.totalMemBytes!)),
      if (caps?.freeStorageBytes != null)
        l10n.aiLocalDeviceFree(
          formatModelBytes(context, caps!.freeStorageBytes!),
        ),
    ];
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.smartphone_outlined),
            title: Text(l10n.aiLocalDeviceTitle),
            subtitle: Text(
              facts.isEmpty ? l10n.aiLocalDeviceUnknown : facts.join(' · '),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi),
            title: Text(l10n.aiLocalWifiOnly),
            subtitle: Text(l10n.aiLocalWifiOnlyHint),
            value: state.wifiOnly,
            onChanged: (v) =>
                ref.read(localModelsControllerProvider.notifier).setWifiOnly(v),
          ),
        ],
      ),
    );
  }
}

class _InstalledTile extends StatelessWidget {
  const _InstalledTile({
    required this.record,
    required this.active,
    required this.onUse,
    required this.onDelete,
  });

  final LocalModelRecord record;
  final bool active;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: active ? scheme.primary : scheme.outline,
      ),
      title: Text(record.label),
      subtitle: Text(
        [
          record.engine.label,
          formatModelBytes(context, record.sizeBytes),
          if (active) l10n.aiLocalInUse,
          if (!record.verified) l10n.aiLocalUnverified,
        ].join(' · '),
      ),
      onTap: active ? null : onUse,
      trailing: PopupMenuButton<String>(
        onSelected: (a) => a == 'use' ? onUse() : onDelete(),
        itemBuilder: (_) => [
          if (!active)
            PopupMenuItem(value: 'use', child: Text(l10n.aiLocalUseModel)),
          PopupMenuItem(value: 'delete', child: Text(l10n.aiDeleteAction)),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.spec,
    required this.task,
    required this.fit,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final LocalModelSpec spec;
  final LocalModelTask? task;
  final RamFit fit;
  final VoidCallback onDownload;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(spec.label, style: theme.textTheme.titleSmall),
                ),
                if (spec.recommended)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.star_outline, size: 16),
                    label: Text(l10n.aiLocalRecommended),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(spec.noteFor(lang), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                RamFitChip(fit: fit),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(formatModelBytes(context, spec.sizeBytes)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    l10n.aiLocalContextShort(
                      formatContextTokens(spec.contextMax),
                    ),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    spec.backends
                        .map((b) => localBackendLabel(l10n, b))
                        .join(' / '),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: spec.license.gated
                      ? const Icon(Icons.lock_outline, size: 16)
                      : null,
                  label: Text(spec.license.id),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _TaskControls(
              task: task,
              onStart: onDownload,
              onPause: onPause,
              onResume: onResume,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// A download from a URL outside the catalog.
class _UrlTaskCard extends StatelessWidget {
  const _UrlTaskCard({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final LocalModelTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final import = task.urlImport!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              import.metadata.displayName,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              import.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _TaskControls(
              task: task,
              onStart: onResume,
              onPause: onPause,
              onResume: onResume,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Download button, or the state of the download with its controls.
class _TaskControls extends StatelessWidget {
  const _TaskControls({
    required this.task,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final LocalModelTask? task;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = task;
    if (t == null) {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonalIcon(
          onPressed: onStart,
          icon: const Icon(Icons.download_outlined),
          label: Text(l10n.aiLocalDownload),
        ),
      );
    }
    final progress = t.totalBytes == null
        ? formatModelBytes(context, t.receivedBytes)
        : l10n.aiLocalProgress(
            formatModelBytes(context, t.receivedBytes),
            formatModelBytes(context, t.totalBytes!),
          );
    final (String status, List<Widget> actions) = switch (t.status) {
      LocalModelTaskStatus.queued => (
        l10n.aiLocalQueued,
        [TextButton(onPressed: onCancel, child: Text(l10n.aiLocalCancel))],
      ),
      LocalModelTaskStatus.downloading => (
        progress,
        [
          TextButton(onPressed: onCancel, child: Text(l10n.aiLocalCancel)),
          FilledButton.tonal(
            onPressed: onPause,
            child: Text(l10n.aiLocalPause),
          ),
        ],
      ),
      LocalModelTaskStatus.paused => (
        l10n.aiLocalPaused(progress),
        [
          TextButton(onPressed: onCancel, child: Text(l10n.aiLocalCancel)),
          FilledButton.tonal(
            onPressed: onResume,
            child: Text(l10n.aiLocalResume),
          ),
        ],
      ),
      LocalModelTaskStatus.waitingForWifi => (
        l10n.aiLocalWaitingForWifi,
        [TextButton(onPressed: onCancel, child: Text(l10n.aiLocalCancel))],
      ),
      LocalModelTaskStatus.verifying => (l10n.aiLocalVerifying, <Widget>[]),
      LocalModelTaskStatus.failed => (
        t.errorCode == null
            ? l10n.errorCodeUnknownError
            : localizeErrorCode(l10n, t.errorCode!),
        [
          TextButton(onPressed: onCancel, child: Text(l10n.aiLocalCancel)),
          FilledButton.tonal(
            onPressed: onResume,
            child: Text(l10n.aiLocalRetry),
          ),
        ],
      ),
    };
    final showBar = t.status != LocalModelTaskStatus.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBar)
          LinearProgressIndicator(
            value:
                t.status == LocalModelTaskStatus.verifying ||
                    t.status == LocalModelTaskStatus.queued
                ? null
                : t.progress,
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: t.status == LocalModelTaskStatus.failed
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ],
    );
  }
}

/// License and size before a download; for gated repositories, the token.
class _LicenseDialog extends ConsumerStatefulWidget {
  const _LicenseDialog({required this.spec});

  final LocalModelSpec spec;

  @override
  ConsumerState<_LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends ConsumerState<_LicenseDialog> {
  final _token = TextEditingController();
  bool? _hasToken;

  @override
  void initState() {
    super.initState();
    if (widget.spec.license.gated) {
      ref.read(huggingFaceTokenStoreProvider).read().then((t) {
        if (mounted) setState(() => _hasToken = t != null);
      });
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  /// `https://huggingface.co/<org>/<repo>`: where a gated license is
  /// accepted.
  String get _repoPage {
    final segments = Uri.parse(widget.spec.url).pathSegments;
    return 'https://huggingface.co/${segments.take(2).join('/')}';
  }

  Future<void> _accept() async {
    if (_token.text.trim().isNotEmpty) {
      await ref.read(huggingFaceTokenStoreProvider).write(_token.text);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spec = widget.spec;
    final gated = spec.license.gated;
    final link = gated ? _repoPage : spec.license.url;
    return AlertDialog(
      title: Text(spec.label),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aiLocalLicenseBody(
                formatModelBytes(context, spec.sizeBytes),
                spec.license.id,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (gated) ...[
              Text(l10n.aiLocalGatedBody),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.aiCopyAction,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => Clipboard.setData(ClipboardData(text: link)),
                ),
              ],
            ),
            if (gated && _hasToken == false) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _token,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.aiLocalTokenLabel,
                  helperText: l10n.aiLocalTokenHelper,
                  helperMaxLines: 3,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.aiLocalCancel),
        ),
        FilledButton(
          onPressed: _accept,
          child: Text(l10n.aiLocalAcceptAndDownload),
        ),
      ],
    );
  }
}

class _ImportDetails {
  const _ImportDetails({required this.metadata, this.url, this.sha256});

  final ModelImportMetadata metadata;
  final String? url;
  final String? sha256;
}

/// Name, quantization and optional checksum of a file outside the catalog
/// (and its https URL for a download).
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({this.fileName, required this.askUrl});

  final String? fileName;
  final bool askUrl;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  final _quant = TextEditingController();
  final _sha = TextEditingController();
  String? _urlError;
  String? _nameError;
  String? _shaError;

  static final _quantPattern = RegExp(
    r'(IQ\d_[A-Z0-9_]+|Q\d(_[A-Z0-9]+)*|BF16|F16|F32|int4|int8)',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    if (widget.fileName != null) _guessFrom(widget.fileName!);
  }

  void _guessFrom(String fileName) {
    final base = fileName.replaceAll(
      RegExp(r'\.(gguf|litertlm|task|bin)$', caseSensitive: false),
      '',
    );
    final quant = _quantPattern.firstMatch(base)?.group(0);
    _quant.text = quant ?? '';
    var name = quant == null ? base : base.replaceFirst(quant, '');
    name = name.replaceAll(RegExp(r'[-_.]+'), ' ').trim();
    _name.text = name.isEmpty ? base : name;
  }

  @override
  void dispose() {
    for (final c in [_url, _name, _quant, _sha]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final url = _url.text.trim();
    final sha = _sha.text.trim().toLowerCase();
    setState(() {
      _urlError = widget.askUrl && Uri.tryParse(url)?.scheme != 'https'
          ? l10n.errorCodeAiLocalDownloadInsecureUrl
          : null;
      _nameError = _name.text.trim().isEmpty
          ? l10n.errorCodeRequiredField
          : null;
      _shaError = sha.isNotEmpty && !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)
          ? l10n.aiLocalShaInvalid
          : null;
    });
    if (_urlError != null || _nameError != null || _shaError != null) return;
    Navigator.of(context).pop(
      _ImportDetails(
        url: widget.askUrl ? url : null,
        sha256: sha.isEmpty ? null : sha,
        metadata: ModelImportMetadata(
          displayName: _name.text.trim(),
          quantization: _quant.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.askUrl ? l10n.aiLocalImportUrl : l10n.aiLocalImportFile,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.askUrl)
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.aiLocalUrlLabel,
                  hintText: 'https://huggingface.co/…/resolve/…/model.gguf',
                  errorText: _urlError,
                ),
                onChanged: (v) {
                  final last = Uri.tryParse(v.trim())?.pathSegments;
                  if (last != null && last.isNotEmpty && _name.text.isEmpty) {
                    _guessFrom(last.last);
                  }
                },
              )
            else
              Text(
                widget.fileName ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: l10n.aiLocalNameLabel,
                errorText: _nameError,
              ),
            ),
            TextField(
              controller: _quant,
              autocorrect: false,
              decoration: InputDecoration(labelText: l10n.aiLocalQuantLabel),
            ),
            TextField(
              controller: _sha,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.aiLocalShaLabel,
                helperText: l10n.aiLocalShaHelper,
                helperMaxLines: 3,
                errorText: _shaError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.aiLocalCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.aiLocalImportAction)),
      ],
    );
  }
}

/// The Hugging Face token for gated repositories. Pops '' to remove it.
class _TokenDialog extends StatefulWidget {
  const _TokenDialog({required this.hasToken});

  final bool hasToken;

  @override
  State<_TokenDialog> createState() => _TokenDialogState();
}

class _TokenDialogState extends State<_TokenDialog> {
  final _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.aiLocalTokenAction),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hasToken ? l10n.aiLocalTokenStored : l10n.aiLocalTokenNone,
          ),
          TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.aiLocalTokenLabel,
              helperText: l10n.aiLocalTokenHelper,
              helperMaxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.hasToken)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.aiApiKeyRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.aiLocalCancel),
        ),
        FilledButton(
          onPressed: () => _token.text.trim().isEmpty
              ? null
              : Navigator.of(context).pop(_token.text.trim()),
          child: Text(l10n.aiSaveSettings),
        ),
      ],
    );
  }
}
