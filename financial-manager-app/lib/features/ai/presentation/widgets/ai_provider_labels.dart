import '../../../../l10n/app_localizations.dart';
import '../../domain/models/ai_settings.dart';

String aiProviderLabel(AppLocalizations l10n, AiProviderKind kind) =>
    switch (kind) {
      AiProviderKind.anthropic => 'Anthropic (Claude)',
      AiProviderKind.openai => 'OpenAI (ChatGPT)',
      AiProviderKind.gemini => 'Google Gemini',
      AiProviderKind.openaiCompatible => l10n.aiProviderCompatible,
      AiProviderKind.onDevice => l10n.aiProviderOnDevice,
    };
