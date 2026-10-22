import '../../../domain/models/local_model.dart';

/// The text of the one user turn sent to the engine.
///
/// flutter_edge_ai sessions take a system instruction and a single user
/// message: chunks added with `addQueryChunk` are joined into it, and the
/// model's own template wraps it. A conversation rebuilt from the server
/// (data, report, earlier questions and answers) is therefore written into
/// that message, each earlier turn tagged with its role, and the latest
/// question last and untagged.
String chatTranscript(List<LocalChatMessage> messages) {
  if (messages.isEmpty) return '';
  if (messages.length == 1) return messages.single.content;
  final b = StringBuffer();
  for (final m in messages.take(messages.length - 1)) {
    final role = m.role == 'assistant' ? 'assistant' : 'user';
    b
      ..write('<previous_turn role="$role">\n')
      ..write(m.content.trim())
      ..write('\n</previous_turn>\n\n');
  }
  b.write(messages.last.content);
  return b.toString();
}
