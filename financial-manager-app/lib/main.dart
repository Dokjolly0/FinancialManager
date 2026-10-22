import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

void main() {
  // In the browser: /app/history instead of /#/app/history (Caddy serves
  // index.html for every path). No effect on the phone.
  usePathUrlStrategy();
  bootstrap(() => const FinancialManagerApp());
}
