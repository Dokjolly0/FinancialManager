/// POST/GET /v1/me/export (plan.md sections 7.13 "Dati", 14.2, 20.2).
class ExportRecord {
  const ExportRecord({
    required this.id,
    required this.format,
    required this.status,
    this.errorMessage,
    this.downloadUrl,
    required this.createdAt,
  });

  final String id;
  final String format;
  final String status;
  final String? errorMessage;
  final String? downloadUrl;
  final DateTime createdAt;

  bool get isReady => status == 'ready';
  bool get isFailed => status == 'failed';

  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      id: json['id'] as String,
      format: json['format'] as String,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      downloadUrl: json['download_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
