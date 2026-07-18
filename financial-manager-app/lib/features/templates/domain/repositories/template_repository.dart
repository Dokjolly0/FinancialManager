import '../../../transactions/domain/models/transaction_direction.dart';
import '../models/transaction_template.dart';

/// Domain-facing template operations (plan.md section 14.6). Create/update
/// are used from the "Nuova operazione" form's "Salva come modello"
/// toggle, fired-and-forgotten after a successful transaction save — the
/// template is a convenience for future autocomplete, not something a
/// failure here should surface as an error to the user.
abstract class TemplateRepository {
  Future<List<TransactionTemplate>> search({
    required TransactionDirection direction,
    String query = '',
    int limit = 8,
  });

  Future<TransactionTemplate> create({
    required TransactionDirection direction,
    required String title,
    String? defaultCategoryId,
    String? defaultDescription,
  });

  Future<TransactionTemplate> update(
    String id, {
    required String title,
    String? defaultCategoryId,
    String? defaultDescription,
  });
}
