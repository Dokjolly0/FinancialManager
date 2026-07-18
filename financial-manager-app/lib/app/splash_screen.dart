import 'package:flutter/material.dart';

/// Splash / session-restore screen (plan.md section 7.1). Shows no
/// financial data until the session is validated — currently there is
/// nothing to validate yet (auth feature lands in Fase 2), so this is a
/// brief branded loading state before [AppRouter]'s redirect sends the
/// user to login.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
