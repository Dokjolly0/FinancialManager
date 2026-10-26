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

/// The history filter value for the transactions without a category
/// (`category_id=none`, plan.md section 17.1), passed wherever a filter
/// takes a category id.
const uncategorizedFilterId = 'none';

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
    this.usageCount = 0,
    this.hidden = false,
  });

  final String id;
  final String name;
  final CategoryDirectionScope directionScope;
  final String? color;
  final bool isSystem;
  final int sortOrder;

  /// How many of the user's transactions use it, over the whole history:
  /// drives the "most used" ordering and the delete warning.
  final int usageCount;

  /// A system category the user hid from the pickers (plan.md section
  /// 11.7). Still listed, so history keeps resolving its name.
  final bool hidden;

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
      usageCount: json['usage_count'] as int? ?? 0,
      hidden: json['hidden'] as bool? ?? false,
    );
  }
}
