import '../../../transactions/domain/models/transaction_direction.dart';

/// Which transaction directions a category applies to (plan.md section
/// 11.7). [both] categories (none seeded by default) show up as a
/// suggestion regardless of whether the operation is an entrata or uscita.
enum CategoryDirectionScope {
  debit,
  credit,
  both;

  static CategoryDirectionScope fromApi(String value) => switch (value) {
    'DEBIT' => CategoryDirectionScope.debit,
    'CREDIT' => CategoryDirectionScope.credit,
    'BOTH' => CategoryDirectionScope.both,
    _ => throw ArgumentError('Unknown category direction scope: $value'),
  };

  String toApi() => switch (this) {
    CategoryDirectionScope.debit => 'DEBIT',
    CategoryDirectionScope.credit => 'CREDIT',
    CategoryDirectionScope.both => 'BOTH',
  };
}

/// Economic classification of a transaction (plan.md section 4.1, 11.7):
/// shared system categories (Casa, Stipendio, ...) plus each user's own
/// custom ones.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.directionScope,
    this.color,
    required this.isSystem,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final CategoryDirectionScope directionScope;
  final String? color;
  final bool isSystem;
  final int sortOrder;

  /// Whether this category should be offered for an operation of the
  /// given [direction] (plan.md section 7.6: "modelli di uscita per
  /// uscite, di entrata per entrate" — the same filtering rule applies to
  /// categories).
  bool matches(TransactionDirection direction) {
    return switch (directionScope) {
      CategoryDirectionScope.both => true,
      CategoryDirectionScope.debit => direction == TransactionDirection.debit,
      CategoryDirectionScope.credit => direction == TransactionDirection.credit,
    };
  }

  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      directionScope: CategoryDirectionScope.fromApi(
        json['direction_scope'] as String,
      ),
      color: json['color'] as String?,
      isSystem: json['is_system'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}
