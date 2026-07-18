import 'package:flutter/material.dart';

/// Stand-in for a route whose real screen has not been built yet. Every
/// route declared in [AppRouter] renders this until its owning feature
/// lands (plan.md section 25 roadmap) — it exists so navigation and
/// guards are exercisable end-to-end today, not to simulate functionality
/// that isn't there.
class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({super.key, required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(routeName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Schermata non ancora implementata: $routeName',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
