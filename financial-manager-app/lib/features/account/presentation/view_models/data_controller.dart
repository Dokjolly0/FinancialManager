import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api/providers.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../../domain/models/export_record.dart';

class DataState {
  const DataState({this.isExporting = false, this.export, this.error});

  final bool isExporting;
  final ExportRecord? export;
  final AppError? error;

  DataState copyWith({
    bool? isExporting,
    ExportRecord? export,
    AppError? error,
    bool clearError = false,
  }) {
    return DataState(
      isExporting: isExporting ?? this.isExporting,
      export: export ?? this.export,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Dati (plan.md section 7.13, 20.2): richiede un export, lo scarica in un
/// file temporaneo e apre il foglio di condivisione nativo cosi' l'utente
/// sceglie dove salvarlo (Files/Drive/email/...), senza permessi di
/// archiviazione su Android.
class DataController extends Notifier<DataState> {
  @override
  DataState build() => const DataState();

  Future<void> requestExport(String format) async {
    state = state.copyWith(isExporting: true, clearError: true);
    try {
      final record = await ref
          .read(accountRepositoryProvider)
          .requestExport(format);
      state = state.copyWith(isExporting: false, export: record);
      if (record.isReady) {
        await _download(record);
      } else if (record.isFailed) {
        state = state.copyWith(
          error: const DomainError(code: 'EXPORT_FAILED', message: ''),
        );
      }
    } on AppError catch (e) {
      state = state.copyWith(isExporting: false, error: e);
    }
  }

  Future<void> _download(ExportRecord record) async {
    final downloadUrl = record.downloadUrl;
    if (downloadUrl == null) return;

    try {
      final repo = ref.read(accountRepositoryProvider);
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get<List<int>>(
        repo.resolveDownloadUrl(downloadUrl),
        options: Options(
          responseType: ResponseType.bytes,
          headers: repo.authHeaders(),
        ),
      );

      final dir = await getTemporaryDirectory();
      final filename = 'export-${record.id}.${record.format}';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.data!);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } on DioException {
      state = state.copyWith(
        error: const DomainError(code: 'EXPORT_FAILED', message: ''),
      );
    }
  }

  Future<void> deleteAccount({String? currentPassword}) async {
    await ref
        .read(accountRepositoryProvider)
        .deleteAccount(currentPassword: currentPassword);
  }
}

final dataControllerProvider = NotifierProvider<DataController, DataState>(
  DataController.new,
);
