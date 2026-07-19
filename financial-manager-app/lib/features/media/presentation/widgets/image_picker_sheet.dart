import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../data/providers.dart';
import '../../domain/models/media_asset.dart';

/// Image picker (plan.md section 7.7): four tabs — Recenti, Libreria,
/// Cerca, Carica. Returns the selected/created [MediaAsset], or `null` if
/// dismissed without a selection.
class ImagePickerSheet extends StatefulWidget {
  const ImagePickerSheet({super.key, required this.kind});

  final MediaKind kind;

  static Future<MediaAsset?> show(
    BuildContext context, {
    required MediaKind kind,
  }) {
    return showModalBottomSheet<MediaAsset?>(
      context: context,
      // See ConfirmationSheet's useRootNavigator comment — otherwise
      // AppShell's centerDocked FAB sits above this sheet's own buttons.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ImagePickerSheet(kind: kind),
    );
  }

  @override
  State<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<ImagePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Recenti'),
                Tab(text: 'Libreria'),
                Tab(text: 'Cerca'),
                Tab(text: 'Carica'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AssetGridTab(kind: widget.kind, sortRecent: true),
                  _AssetGridTab(kind: widget.kind, sortRecent: false),
                  _SearchTab(kind: widget.kind),
                  _UploadTab(kind: widget.kind),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetGridTab extends ConsumerStatefulWidget {
  const _AssetGridTab({required this.kind, required this.sortRecent});

  final MediaKind kind;
  final bool sortRecent;

  @override
  ConsumerState<_AssetGridTab> createState() => _AssetGridTabState();
}

class _AssetGridTabState extends ConsumerState<_AssetGridTab> {
  late Future<List<MediaAsset>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(mediaRepositoryProvider)
        .list(kind: widget.kind, sortRecent: widget.sortRecent);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(mediaRepositoryProvider);

    return FutureBuilder<List<MediaAsset>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return InlineError(
            message: 'Impossibile caricare le immagini.',
            onRetry: () => setState(() {
              _future = repo.list(
                kind: widget.kind,
                sortRecent: widget.sortRecent,
              );
            }),
          );
        }
        final assets = snapshot.data!;
        if (assets.isEmpty) {
          return const EmptyState(message: 'Nessuna immagine disponibile.');
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.xs,
            mainAxisSpacing: AppSpacing.xs,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(asset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                child: Image(
                  image: NetworkImage(
                    repo.contentUrl(asset.id),
                    headers: repo.authHeaders(),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab({required this.kind});

  final MediaKind kind;

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MediaSearchResult> _results = [];
  bool _isSearching = false;
  bool _isSelecting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await ref
          .read(mediaRepositoryProvider)
          .search(query: query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = 'Ricerca non disponibile al momento.';
      });
    }
  }

  Future<void> _select(MediaSearchResult result) async {
    setState(() => _isSelecting = true);
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .selectFromSearch(
            kind: widget.kind,
            provider: 'unsplash',
            externalId: result.externalId,
          );
      if (mounted) Navigator.of(context).pop(asset);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSelecting = false;
          _error = 'Impossibile selezionare questa immagine.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Cerca immagini',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: _onChanged,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              _results.isEmpty
                  ? EmptyState(
                      message: _controller.text.trim().length < 2
                          ? 'Digita almeno 2 caratteri per cercare.'
                          : 'Nessun risultato.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: AppSpacing.xs,
                            mainAxisSpacing: AppSpacing.xs,
                          ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return GestureDetector(
                          onTap: _isSelecting ? null : () => _select(result),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.inputRadius,
                            ),
                            child: Image.network(
                              result.thumbUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
              if (_isSelecting)
                const ColoredBox(
                  color: Colors.black26,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadTab extends ConsumerStatefulWidget {
  const _UploadTab({required this.kind});

  final MediaKind kind;

  @override
  ConsumerState<_UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends ConsumerState<_UploadTab> {
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() => _error = null);
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 95,
    );
    if (picked == null || !mounted) return;

    // plan.md section 7.8: 1:1 crop, circular preview mask for profile.
    final isProfile = widget.kind == MediaKind.profile;
    final cropStyle = isProfile ? CropStyle.circle : CropStyle.rectangle;
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ritaglia immagine',
          lockAspectRatio: true,
          cropStyle: cropStyle,
        ),
        IOSUiSettings(title: 'Ritaglia immagine', cropStyle: cropStyle),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await File(cropped.path).readAsBytes();
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadFile(kind: widget.kind, bytes: bytes, filename: picked.name);
      if (mounted) Navigator.of(context).pop(asset);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'Caricamento non riuscito. Riprova.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _isUploading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => _pickAndUpload(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotocamera'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => _pickAndUpload(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galleria'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
