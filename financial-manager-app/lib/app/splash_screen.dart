import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session/session_restore.dart';

/// Splash / session-restore screen (plan.md section 7.1). Shows no
/// financial data until the session is validated. Watching
/// [sessionRestoreProvider] triggers the restore-session attempt on first
/// build; once it resolves, [sessionControllerProvider] reflects the
/// outcome and the router redirects away from here.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionRestoreProvider);

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 64),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
