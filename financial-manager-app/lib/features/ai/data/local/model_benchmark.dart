import '../../domain/local/local_llm_engine.dart';
import '../../domain/models/local_model.dart';
import '../../domain/models/local_model_catalog.dart';

/// "Misura velocità": about 1,000 tokens in and up to 128 out with the
/// active model, recorded like a real run so time estimates use it.
class ModelBenchmark {
  ModelBenchmark(this._host);

  final LocalModelHost _host;

  static const _system =
      'Sei un assistente che riassume movimenti bancari in italiano.';

  /// Forty made-up transactions: about 1,000 tokens on the catalog models.
  static String get prompt {
    const items = [
      ('Spesa alimentare', 'Esselunga', '54,30'),
      ('Trasporti', 'Carburante Q8', '62,00'),
      ('Casa', 'Bolletta luce', '103,06'),
      ('Svago', 'Cinema', '18,50'),
      ('Salute', 'Farmacia', '12,90'),
    ];
    final b = StringBuffer('Movimenti del mese:\n');
    for (var i = 0; i < 40; i++) {
      final (category, payee, amount) = items[i % items.length];
      b.writeln(
        '- 2026-03-${(i % 28 + 1).toString().padLeft(2, '0')} · $category · '
        '$payee · -$amount EUR',
      );
    }
    b.write('Riassumi in tre frasi dove sono andati i soldi.');
    return b.toString();
  }

  Future<LocalSpeed> run() async {
    final session = await _host.acquire();
    final params = session.params.copyWith(maxOutputTokens: 128);
    LocalGenStats? stats;
    await for (final e in session.engine.generate(
      LocalChatRequest(
        system: _system,
        messages: [LocalChatMessage(role: 'user', content: prompt)],
        params: params,
      ),
    )) {
      if (e is LocalGenStats) stats = e;
    }
    final s = stats;
    if (s == null || s.prefillMs <= 0 || s.decodeMs <= 0) {
      throw const LocalEngineException(LocalErrorCodes.engine, 'no stats');
    }
    _host.recordSpeed(session, s);
    return LocalSpeed(
      prefillTps: s.promptTokens / (s.prefillMs / 1000),
      decodeTps: (s.outputTokens - 1).clamp(1, 1 << 20) / (s.decodeMs / 1000),
    );
  }
}
