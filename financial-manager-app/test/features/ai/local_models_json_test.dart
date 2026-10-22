import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';

void main() {
  test('settings carry the on-device path', () {
    final s = AiSettings.fromJson({
      'available': false,
      'on_device_available': true,
      'mode': 'on_device',
      'local_model': 'Qwen3 4B · Q4_K_M',
      'consent': {
        'current_version': 1,
        'required': true,
        'on_device': {
          'accepted_version': 1,
          'current_version': 1,
          'required': false,
        },
      },
    });
    expect(s.anyAvailable, isTrue);
    expect(s.mode, AiMode.onDevice);
    expect(s.localModel, 'Qwen3 4B · Q4_K_M');
    expect(s.localConsent!.required, isFalse);
    expect(AiProviderKind.cloud, isNot(contains(AiProviderKind.onDevice)));
    expect(AiProviderKind.fromWire('on_device'), AiProviderKind.onDevice);
  });

  test('preview context fit and compaction', () {
    final p = AiPreview.fromJson({
      'provider': 'on_device',
      'model': 'Qwen3 4B',
      'system_prompt': 's',
      'instructions': 'i',
      'data_block': 'd',
      'data_fingerprint': 'f',
      'period_to': '2026-10-20',
      'target': 'on_device',
      'context_fit': {
        'context_tokens': 8000,
        'input_tokens': 5000,
        'reserved_output_tokens': 2000,
        'fits': true,
      },
      'disclosure': {
        'profile': 'compact',
        'compaction_steps': ['transactions_30'],
      },
    });
    expect(p.target, AiMode.onDevice);
    expect(p.contextFit!.usage, closeTo(0.875, 1e-9));
    expect(p.disclosure.profile, 'compact');
    expect(p.disclosure.compactionSteps, ['transactions_30']);
  });

  test('history items keep the runtime of on-device analyses', () {
    final a = AiAnalysisSummary.fromJson({
      'id': 'a',
      'title': 't',
      'preset': 'SAVINGS',
      'period_to': '2026-10-20',
      'status': 'COMPLETED',
      'provider': 'on_device',
      'model': 'Qwen3 4B · Q4_K_M · llama.cpp',
      'created_at': '2026-10-20T08:00:00Z',
      'runtime': {
        'engine': 'llama_cpp',
        'model_id': 'qwen3-4b',
        'display_name': 'Qwen3 4B',
        'quantization': 'Q4_K_M',
        'backend': 'gpu',
        'context_tokens': 8192,
        'max_output_tokens': 1024,
      },
    });
    expect(a.isOnDevice, isTrue);
    expect(a.runtime!.engine, LocalEngineKind.llamaCpp);
    expect(a.runtime!.backend, LocalBackend.gpu);
    expect(
      AiMessage.fromJson({
        'id': 'm',
        'kind': 'REPORT',
        'status': 'COMPLETED',
        'duration_ms': 1200,
      }).durationMs,
      1200,
    );
  });

  test('request carries profile, budget, target and device', () {
    final json = const AiAnalysisRequest(
      preset: 'SAVINGS',
      profile: 'compact',
      budgetTokens: 5000,
      target: 'on_device',
      device: AiDeviceParams(contextTokens: 8192, maxOutputTokens: 1024),
    ).toJson();
    expect(json['target'], 'on_device');
    expect(json['device'], {'context_tokens': 8192, 'max_output_tokens': 1024});
    final options = json['options'] as Map<String, dynamic>;
    expect((options['profile'], options['budget_tokens']), ('compact', 5000));
    final plain = const AiAnalysisRequest(preset: 'SAVINGS').toJson();
    expect(plain.containsKey('target'), isFalse);
    expect((plain['options'] as Map).containsKey('profile'), isFalse);
  });

  test('local turn and result round-trip', () {
    final turn = AiLocalTurn.fromJson({
      'analysis_id': 'a',
      'message_id': 'm',
      'kind': 'ANSWER',
      'system_prompt': 's',
      'messages': [
        {'role': 'user', 'content': 'x'},
      ],
      'max_output_tokens': 512,
      'deadline_at': '2026-10-20T09:00:00Z',
    });
    expect(turn.isReport, isFalse);
    expect(turn.messages.single.content, 'x');
    const r = AiLocalResult(
      content: 'c',
      status: 'FAILED',
      errorCode: 'AI_LOCAL_TIMEOUT',
      durationMs: 5,
    );
    expect(AiLocalResult.fromJson(r.toJson()).errorCode, 'AI_LOCAL_TIMEOUT');
  });
}
