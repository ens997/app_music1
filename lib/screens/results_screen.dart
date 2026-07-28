// lib/screens/results_screen.dart
import 'package:flutter/material.dart';
import '../core/core.dart';

class ResultsScreen extends StatelessWidget {
  final String summary;
  final Exercise? exercise;

  const ResultsScreen({
    Key? key,
    required this.summary,
    this.exercise,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '📊 Resultados',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (exercise != null) ...[
              Text('Ejercicio: ${exercise!.title}'),
              Text('Compositor: ${exercise!.composer}'),
              const Divider(),
            ],
            Text(summary),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('Volver al Menú'),
            ),
          ],
        ),
      ),
    );
  }
}