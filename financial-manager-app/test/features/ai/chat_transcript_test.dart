import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/local/engines/chat_transcript.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';

void main() {
  test('a single message is sent as is', () {
    expect(chatTranscript(const []), '');
    expect(
      chatTranscript(const [
        LocalChatMessage(role: 'user', content: 'dati', kind: 'CONTEXT'),
      ]),
      'dati',
    );
  });

  test('each earlier part is tagged by kind and the question comes last', () {
    final t = chatTranscript(const [
      LocalChatMessage(role: 'user', content: 'dati\n', kind: 'CONTEXT'),
      LocalChatMessage(role: 'assistant', content: 'report', kind: 'REPORT'),
      LocalChatMessage(role: 'user', content: 'q1', kind: 'QUESTION'),
      LocalChatMessage(role: 'assistant', content: ' a1 ', kind: 'ANSWER'),
      LocalChatMessage(
        role: 'user',
        content: '<follow_up_question>\nperché?\n</follow_up_question>',
        kind: 'QUESTION',
      ),
    ]);
    expect(
      t,
      '<initial_request_and_data>\ndati\n</initial_request_and_data>\n\n'
      '<report_already_written>\nreport\n</report_already_written>\n\n'
      '<previous_question>\nq1\n</previous_question>\n\n'
      '<previous_answer>\na1\n</previous_answer>\n\n'
      '<follow_up_question>\nperché?\n</follow_up_question>',
    );
  });

  test('without kinds (older server) earlier turns are tagged by role', () {
    final t = chatTranscript(const [
      LocalChatMessage(role: 'user', content: 'dati'),
      LocalChatMessage(role: 'assistant', content: 'report\n'),
      LocalChatMessage(role: 'user', content: 'perché?'),
    ]);
    expect(
      t,
      '<previous_turn role="user">\ndati\n</previous_turn>\n\n'
      '<previous_turn role="assistant">\nreport\n</previous_turn>\n\n'
      'perché?',
    );
  });

  test('an unknown kind falls back to the role tag', () {
    final t = chatTranscript(const [
      LocalChatMessage(role: 'assistant', content: 'x', kind: 'SOMETHING'),
      LocalChatMessage(role: 'user', content: 'q'),
    ]);
    expect(t, '<previous_turn role="assistant">\nx\n</previous_turn>\n\nq');
  });
}
