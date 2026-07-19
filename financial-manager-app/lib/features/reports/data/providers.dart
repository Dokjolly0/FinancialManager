import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/repositories/report_repository.dart';
import 'repositories/report_repository_impl.dart';
import 'services/report_api.dart';

final reportApiProvider = Provider<ReportApi>((ref) {
  return ReportApi(ref.watch(apiClientProvider).dio);
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(ref.watch(reportApiProvider));
});
