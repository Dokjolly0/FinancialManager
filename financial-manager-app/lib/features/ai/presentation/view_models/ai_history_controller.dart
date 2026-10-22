import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis.dart';

class AiHistoryState {
  const AiHistoryState({
    this.items = const [],
    this.nextCursor,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<AiAnalysisSummary> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final AppError? error;

  bool get hasMore => nextCursor != null;
}

/// The analysis history, newest first, loaded page by page.
class AiHistoryController extends Notifier<AiHistoryState> {
  @override
  AiHistoryState build() {
    Future.microtask(refresh);
    return const AiHistoryState();
  }

  Future<void> refresh() async {
    try {
      final page = await ref.read(aiRepositoryProvider).listAnalyses();
      state = AiHistoryState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } on AppError catch (e) {
      state = AiHistoryState(items: state.items, isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = AiHistoryState(
      items: state.items,
      nextCursor: state.nextCursor,
      isLoading: false,
      isLoadingMore: true,
    );
    try {
      final page = await ref
          .read(aiRepositoryProvider)
          .listAnalyses(cursor: state.nextCursor);
      state = AiHistoryState(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        isLoading: false,
      );
    } on AppError catch (e) {
      state = AiHistoryState(
        items: state.items,
        nextCursor: state.nextCursor,
        isLoading: false,
        error: e,
      );
    }
  }

  /// Removes optimistically; restores the list if the server refuses.
  Future<AppError?> delete(String id) async {
    final before = state;
    state = AiHistoryState(
      items: state.items.where((a) => a.id != id).toList(),
      nextCursor: state.nextCursor,
      isLoading: false,
    );
    try {
      await ref.read(aiRepositoryProvider).deleteAnalysis(id);
      ref.invalidate(aiSettingsProvider);
      return null;
    } on AppError catch (e) {
      state = before;
      return e;
    }
  }

  Future<AppError?> deleteAll() async {
    try {
      await ref.read(aiRepositoryProvider).deleteAllAnalyses();
      state = const AiHistoryState(isLoading: false);
      ref.invalidate(aiSettingsProvider);
      return null;
    } on AppError catch (e) {
      return e;
    }
  }

  Future<AppError?> rename(String id, String title) async {
    try {
      final detail = await ref
          .read(aiRepositoryProvider)
          .renameAnalysis(id, title);
      state = AiHistoryState(
        items: [for (final a in state.items) a.id == id ? detail.summary : a],
        nextCursor: state.nextCursor,
        isLoading: false,
      );
      return null;
    } on AppError catch (e) {
      return e;
    }
  }
}

final aiHistoryControllerProvider =
    NotifierProvider.autoDispose<AiHistoryController, AiHistoryState>(
      AiHistoryController.new,
    );
