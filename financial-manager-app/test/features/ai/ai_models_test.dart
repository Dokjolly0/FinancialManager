import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/api/sse.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/ai_stream_event.dart';
import 'package:financialmanager/features/ai/domain/models/ai_user_context.dart';

void main() {
  test('AiSettings.fromJson parses the backend shape', () {
    final settings = AiSettings.fromJson({
      'available': true,
      'active': {
        'id': 'c1',
        'provider': 'openai_compatible',
        'base_url': 'https://api.mistral.ai/v1',
        'model': 'mistral-large',
        'has_key': true,
        'key_hint': 'sk-…a1b2',
        'last_tested_at': '2026-10-20T08:00:00Z',
        'last_test_ok': true,
      },
      'credentials': [
        {
          'id': 'c1',
          'provider': 'openai_compatible',
          'base_url': 'https://api.mistral.ai/v1',
          'has_key': true,
        },
        {'id': 'c2', 'provider': 'anthropic', 'has_key': true},
      ],
      'max_output_tokens': 2048,
      'input_price_per_mtok': 2,
      'output_price_per_mtok': null,
      'defaults': {'include_transactions': true, 'anonymize_titles': false},
      'consent': {
        'accepted_version': null,
        'current_version': 1,
        'accepted_at': null,
        'required': true,
      },
      'setup': {
        'has_provider': true,
        'has_model': true,
        'has_context': false,
        'wallets_total': 2,
        'wallets_with_purpose': 2,
        'analyses_count': 0,
      },
      'version': 3,
    });

    expect(settings.active!.provider, AiProviderKind.openaiCompatible);
    expect(settings.active!.keyHint, 'sk-…a1b2');
    expect(settings.inputPricePerMTok, 2.0);
    expect(settings.defaultIncludeTransactions, isTrue);
    expect(settings.consent.required, isTrue);
    expect(settings.isReady, isFalse, reason: 'consent is still required');
    expect(settings.setup.stepsDone, 2);
    expect(settings.credentialFor(AiProviderKind.anthropic)!.id, 'c2');
    expect(
      settings.credentialFor(
        AiProviderKind.openaiCompatible,
        baseUrl: 'https://other/v1',
      ),
      isNull,
    );
  });

  test('AiSettings.fromJson handles a disabled server', () {
    final settings = AiSettings.fromJson({
      'available': false,
      'credentials': [],
      'consent': {'current_version': 1, 'required': true},
    });
    expect(settings.available, isFalse);
    expect(settings.active, isNull);
    expect(settings.setup.stepsDone, 0);
  });

  test('SaveAiSettingsParams only sends api_key when set', () {
    const keep = SaveAiSettingsParams(
      provider: AiProviderKind.anthropic,
      model: 'claude',
      maxOutputTokens: 4096,
      expectedVersion: 1,
    );
    expect(keep.toJson().containsKey('api_key'), isFalse);
    const clear = SaveAiSettingsParams(
      provider: AiProviderKind.anthropic,
      model: 'claude',
      apiKey: '',
      maxOutputTokens: 4096,
      expectedVersion: 1,
    );
    expect(clear.toJson()['api_key'], '');
    expect(clear.toJson()['provider'], 'anthropic');
  });

  test('AiAnalysisRequest.toJson', () {
    final request = AiAnalysisRequest(
      preset: 'CUSTOM',
      periodPreset: 'custom',
      customFrom: DateTime(2026, 6, 1),
      customTo: DateTime(2026, 6, 30),
      walletIds: const ['w1'],
      sections: const {AiDataSection.titles, AiDataSection.monthly},
      includeTransactions: true,
      maxTransactions: 50,
      anonymizeTitles: true,
      instructions: 'Quanto spendo?',
    );
    final json = request.toJson();
    expect(json['period'], {
      'preset': 'custom',
      'from': '2026-06-01',
      'to': '2026-06-30',
    });
    final options = json['options'] as Map<String, dynamic>;
    expect(options['sections'], ['monthly', 'titles'], reason: 'stable order');
    expect(options['max_transactions'], 50);
    expect(json['instructions'], 'Quanto spendo?');

    final defaults = const AiAnalysisRequest(preset: 'SAVINGS').toJson();
    expect(defaults['period'], {'preset': 'last_12_months'});
    expect(defaults['instructions'], isNull);
  });

  test('AiPreset and AiPreview parse', () {
    final preset = AiPreset.fromJson({
      'id': 'ANOMALIES',
      'title': 'Spese insolite',
      'description': 'Picchi',
      'default_instructions': 'Cerca le anomalie',
      'default_sections': ['monthly', 'unknown_future_section'],
      'default_include_transactions': true,
      'default_period_preset': 'last_12_months',
    });
    expect(preset.defaultSections, {AiDataSection.monthly});
    expect(preset.isCustom, isFalse);

    final preview = AiPreview.fromJson({
      'provider': 'gemini',
      'model': 'gemini-x',
      'prompt_version': 'v1',
      'system_prompt': 'sys',
      'instructions': 'istr',
      'data_block': '<financial_data>…</financial_data>',
      'data_fingerprint': 'f' * 64,
      'estimated_input_tokens': 1234,
      'max_output_tokens': 4096,
      'estimated_cost': {'input_cost': 0.01, 'max_output_cost': 0.04},
      'period_from': null,
      'period_to': '2026-10-20',
      'disclosure': {
        'sections': ['titles'],
        'wallet_count': 2,
        'transaction_count': 0,
        'transactions_omitted': 0,
        'anonymized': true,
        'includes_personal_context': false,
      },
    });
    expect(preview.provider, AiProviderKind.gemini);
    expect(preview.estimatedMaxCost, closeTo(0.05, 1e-9));
    expect(preview.periodFrom, isNull);
    expect(preview.disclosure.anonymized, isTrue);
  });

  test('AiAnalysisDetail parses the conversation', () {
    final detail = AiAnalysisDetail.fromJson({
      'id': 'a1',
      'title': 'Check-up',
      'preset': 'MONTHLY_CHECKUP',
      'period_from': '2025-10-20',
      'period_to': '2026-10-20',
      'status': 'COMPLETED',
      'provider': 'anthropic',
      'model': 'claude',
      'input_tokens': 100,
      'output_tokens': 20,
      'cost': null,
      'created_at': '2026-10-20T08:00:00Z',
      'system_prompt': 'sys',
      'follow_ups_left': 19,
      'can_ask_follow_ups': true,
      'messages': [
        {
          'id': 'm1',
          'kind': 'CONTEXT',
          'content': 'dati',
          'status': 'COMPLETED',
        },
        {
          'id': 'm2',
          'kind': 'REPORT',
          'content': '## Sintesi',
          'status': 'COMPLETED',
          'truncated': true,
        },
      ],
    });
    expect(detail.summary.status, AiStatus.completed);
    expect(detail.contextMessage!.content, 'dati');
    expect(detail.messages[1].truncated, isTrue);
    expect(detail.messages[0].fromUser, isTrue);
  });

  test('AiStreamEvent.fromSse maps every event and ignores unknown ones', () {
    AiStreamEvent? map(String event, String data) =>
        AiStreamEvent.fromSse(SseEvent(event: event, data: data));

    expect(
      map('meta', '{"analysis_id":"a","message_id":"m","kind":"ANSWER"}'),
      isA<AiStreamMeta>().having((e) => e.kind, 'kind', AiMessageKind.answer),
    );
    expect(
      map('delta', '{"text":"ciao"}'),
      isA<AiStreamDelta>().having((e) => e.text, 'text', 'ciao'),
    );
    expect(
      map('usage', '{"input_tokens":1,"output_tokens":2,"truncated":true}'),
      isA<AiStreamUsage>().having((e) => e.truncated, 'truncated', isTrue),
    );
    expect(
      map('error', '{"code":"AI_PROVIDER_UNAVAILABLE","message":"Overloaded"}'),
      isA<AiStreamError>().having(
        (e) => e.code,
        'code',
        'AI_PROVIDER_UNAVAILABLE',
      ),
    );
    expect(
      map('done', '{"status":"CANCELLED"}'),
      isA<AiStreamDone>().having((e) => e.status, 'status', AiStatus.cancelled),
    );
    expect(
      map(
        'tool',
        '{"name":"sum_transactions","query":"benzina","group_by":"month"}',
      ),
      isA<AiStreamTool>().having((e) => e.isSum, 'isSum', isTrue).having(
        (e) => (e.query, e.groupBy),
        'args',
        ('benzina', 'month'),
      ),
    );
    expect(map('something_new', '{}'), isNull);
  });

  test('a chat answer parses its tool trace', () {
    final m = AiMessage.fromJson({
      'id': 'a',
      'kind': 'ANSWER',
      'content': 'Il 1 giugno.',
      'status': 'COMPLETED',
      'tool_trace': [
        {
          'name': 'search_transactions',
          'args': {'query': 'assicurazione'},
          'result': '<financial_data>…</financial_data>',
          'rows': 1,
        },
      ],
    });
    final e = m.toolTrace.single;
    expect((e.isSum, e.query, e.rows), (false, 'assicurazione', 1));
    expect(m.copyWith(content: 'x').toolTrace, hasLength(1));
    expect(
      AiMessage.fromJson({
        'id': 'b',
        'kind': 'ANSWER',
        'tool_trace': null,
      }).toolTrace,
      isEmpty,
    );
  });

  test('chats: request, detail question, message attachment', () {
    final body = AiAnalysisRequest.chat(
      '  Quando ho pagato?  ',
      profile: 'compact',
      budgetTokens: 9000,
      target: 'on_device',
    ).toJson();
    expect(body['preset'], 'CHAT');
    expect(body['instructions'], 'Quando ho pagato?');
    expect(body['period'], {'preset': 'all_time'});
    final options = body['options'] as Map<String, dynamic>;
    expect(options['sections'], isEmpty, reason: 'the server picks them');
    expect(options['max_transactions'], aiChatMaxTransactions);
    expect((options['profile'], options['budget_tokens']), ('compact', 9000));

    final detail = AiAnalysisDetail.fromJson({
      'id': 'a1',
      'title': 'Quando ho pagato?',
      'preset': 'CHAT',
      'period_from': null,
      'period_to': '2026-10-25',
      'status': 'COMPLETED',
      'provider': 'openai',
      'model': 'gpt-test',
      'created_at': '2026-10-25T08:00:00Z',
      'question': 'Quando ho pagato?',
      'messages': [
        {
          'id': 'q',
          'kind': 'QUESTION',
          'content': 'E il bollo?',
          'status': 'COMPLETED',
          'attachment': 'MATCHES',
        },
        {
          'id': 'a',
          'kind': 'ANSWER',
          'content': 'Il 1 luglio.',
          'status': 'COMPLETED',
          'attachment': null,
        },
      ],
    });
    expect(detail.summary.isChat, isTrue);
    expect(detail.question, 'Quando ho pagato?');
    expect(detail.messages.map((m) => m.attachment), ['MATCHES', null]);
    expect(detail.messages.first.copyWith(content: 'x').attachment, 'MATCHES');
  });

  test('AiUserContext round-trips', () {
    final context = AiUserContext.fromJson({
      'household_size': 3,
      'income_type': 'EMPLOYEE',
      'about_me': null,
      'goals': 'Risparmiare',
      'ignore_notes': null,
      'response_style': 'CONCISE',
      'version': 2,
      'updated_at': '2026-10-20T08:00:00Z',
    });
    expect(context.isEmpty, isFalse);
    expect(context.toJson()['version'], 2);
    expect(const AiUserContext().isEmpty, isTrue);
  });
}
