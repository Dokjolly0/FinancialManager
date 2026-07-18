import '../../../transactions/domain/models/transaction_direction.dart';

/// Mirrors transactions.NormalizeTitle server-side (plan.md section 4.4):
/// trim, compact internal spaces, case-insensitive comparison. Used
/// client-side to detect when an edited title no longer matches the
/// template the user picked from autocomplete.
String normalizeTemplateTitle(String title) {
  return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// A reusable title/category/description bundle for frequent operations
/// (plan.md section 4.1, 11.9), surfaced as title autocomplete in "Nuova
/// operazione" (section 7.6).
class TransactionTemplate {
  const TransactionTemplate({
    required this.id,
    required this.direction,
    required this.title,
    this.defaultCategoryId,
    this.defaultDescription,
    required this.usageCount,
  });

  final String id;
  final TransactionDirection direction;
  final String title;
  final String? defaultCategoryId;
  final String? defaultDescription;
  final int usageCount;

  static TransactionTemplate fromJson(Map<String, dynamic> json) {
    return TransactionTemplate(
      id: json['id'] as String,
      direction: TransactionDirection.fromApi(json['direction'] as String),
      title: json['title'] as String,
      defaultCategoryId: json['default_category_id'] as String?,
      defaultDescription: json['default_description'] as String?,
      usageCount: json['usage_count'] as int,
    );
  }
}
