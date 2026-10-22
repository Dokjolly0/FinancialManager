import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../../domain/models/ai_analysis.dart';
import '../../domain/models/ai_analysis_request.dart';

class AiDraftState {
  const AiDraftState({
    this.request,
    this.preview,
    this.isLoading = false,
    this.error,
  });

  final AiAnalysisRequest? request;
  final AiPreview? preview;
  final bool isLoading;
  final AppError? error;
}

/// The analysis being prepared: the request built on the setup screen and
/// the preview the user reviews before sending. Kept outside the routes
/// (not as go_router `extra`) so it survives navigation between setup,
/// preview and the run.
class AiDraftController extends Notifier<AiDraftState> {
  @override
  AiDraftState build() => const AiDraftState();

  /// Builds the preview of [request]; true on success.
  Future<bool> preview(AiAnalysisRequest request) async {
    state = AiDraftState(
      request: request,
      preview: state.preview,
      isLoading: true,
    );
    try {
      final preview = await ref.read(aiRepositoryProvider).preview(request);
      state = AiDraftState(request: request, preview: preview);
      return true;
    } on AppError catch (e) {
      state = AiDraftState(request: request, error: e);
      return false;
    }
  }

  /// Rebuilds the preview after AI_DATA_CHANGED, keeping the edited
  /// instructions.
  Future<bool> refresh({String? instructions}) {
    final request = state.request;
    if (request == null) return Future.value(false);
    return preview(request.copyWith(instructions: instructions));
  }

  void setInstructions(String instructions) {
    final request = state.request;
    if (request == null) return;
    state = AiDraftState(
      request: request.copyWith(instructions: instructions),
      preview: state.preview,
    );
  }
}

/// Registered in user_scoped_providers.dart.
final aiDraftControllerProvider =
    NotifierProvider<AiDraftController, AiDraftState>(AiDraftController.new);
