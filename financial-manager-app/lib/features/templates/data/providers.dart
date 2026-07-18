import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../domain/repositories/template_repository.dart';
import 'repositories/template_repository_impl.dart';
import 'services/template_api.dart';

final templateApiProvider = Provider<TemplateApi>((ref) {
  return TemplateApi(ref.watch(apiClientProvider).dio);
});

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepositoryImpl(ref.watch(templateApiProvider));
});
