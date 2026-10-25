import '../../../domain/models/local_model.dart';

/// The text of the one user turn sent to the engine.
///
/// flutter_edge_ai sessions take a system instruction and a single user
/// message: chunks added with `addQueryChunk` are joined into it, and the
/// model's own template wraps it. A conversation rebuilt from the server
/// (data, report, earlier questions and answers) is therefore written into
/// that message, each earlier part tagged with what it is, and the latest
/// question (already wrapped by the server) last and untagged. Without
/// kinds (older servers) earlier turns are tagged with their role only.
String chatTranscript(List<LocalChatMessage> messages) {
  if (messages.isEmpty) return '';
  if (messages.length == 1) return messages.single.content;
  final b = StringBuffer();
  for (final m in messages.take(messages.length - 1)) {
    final (open, close) = _tags(m);
    b
      ..write('$open\n')
      ..write(m.content.trim())
      ..write('\n$close\n\n');
  }
  b.write(messages.last.content);
  return b.toString();
}

(String, String) _tags(LocalChatMessage m) {
  final tag = switch (m.kind) {
    'CONTEXT' => 'initial_request_and_data',
    'REPORT' => 'report_already_written',
    'QUESTION' => 'previous_question',
    'ANSWER' => 'previous_answer',
    _ => null,
  };
  if (tag != null) return ('<$tag>', '</$tag>');
  final role = m.role == 'assistant' ? 'assistant' : 'user';
  return ('<previous_turn role="$role">', '</previous_turn>');
}
