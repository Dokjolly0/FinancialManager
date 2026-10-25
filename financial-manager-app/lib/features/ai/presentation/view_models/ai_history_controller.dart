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
    this.type,
  });

  final List<AiAnalysisSummary> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final AppError? error;

  /// Only reports or only chats; null lists both.
  final AiHistoryType? type;

  bool get hasMore => nextCursor != null;
}

/// The analysis history, newest first, loaded page by page.
class AiHistoryController extends Notifier<AiHistoryState> {
  AiHistoryType? _type;

  @override
  AiHistoryState build() {
    Future.microtask(refresh);
    return const AiHistoryState();
  }

  /// Lists only [type] (null: everything) from the first page.
  Future<void> setType(AiHistoryType? type) {
    if (type == _type) return Future.value();
    _type = type;
    state = AiHistoryState(type: type);
    return refresh();
  }

  Future<void> refresh() async {
    final type = _type;
    try {
      final page = await ref
          .read(aiRepositoryProvider)
          .listAnalyses(type: type);
      if (type != _type) return; // the filter changed meanwhile
      state = AiHistoryState(
        items: page.items,
        nextCursor: page.nextCursor,
        isLoading: false,
        type: type,
      );
    } on AppError catch (e) {
      if (type != _type) return;
      state = AiHistoryState(
        items: state.items,
        isLoading: false,
        error: e,
        type: type,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    final type = _type;
    state = AiHistoryState(
      items: state.items,
      nextCursor: state.nextCursor,
      isLoading: false,
      isLoadingMore: true,
      type: type,
    );
    try {
      final page = await ref
          .read(aiRepositoryProvider)
          .listAnalyses(cursor: state.nextCursor, type: type);
      if (type != _type) return;
      state = AiHistoryState(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        isLoading: false,
        type: type,
      );
    } on AppError catch (e) {
      if (type != _type) return;
      state = AiHistoryState(
        items: state.items,
        nextCursor: state.nextCursor,
        isLoading: false,
        error: e,
        type: type,
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
      type: _type,
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
      state = AiHistoryState(isLoading: false, type: _type);
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
        type: _type,
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
