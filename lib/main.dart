import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/screens.dart';
import 'providers/exercise_provider.dart'; // <-- Importa el provider
import 'core/core.dart'; // <-- Necesario para ExerciseStats
import 'services/latency_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LatencySettingsService.load();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExerciseProvider()..loadExercises(),
      child: const MusicTrainingApp(),
    ),
  );
}

class MusicTrainingApp extends StatelessWidget {
  const MusicTrainingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entrenador Musical',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4ecca3),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final exerciseProvider = context.watch<ExerciseProvider>();
    final exercises = exerciseProvider.exercises;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Entrenador Musical Pro'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (exercises.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${exercises.length} ejercicios',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '𝄞',
                    style: TextStyle(
                      fontSize: 80,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Bienvenido al Entrenador Musical',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sistema avanzado de entrenamiento musical con ejercicios '
                  'precargados, metrónomo automático y análisis de precisión rítmica.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                _buildMenuButton(
                  context,
                  icon: Icons.music_note,
                  title: '🎯 Elegir Ejercicios',
                  description: exerciseProvider.isLoading
                      ? 'Cargando ejercicios...'
                      : exerciseProvider.error != null
                      ? '⚠️ ${exerciseProvider.error}'
                      : exercises.isEmpty
                      ? '📂 No hay ejercicios disponibles'
                      : '📚 ${exercises.length} ejercicios listos para practicar',
                  onPressed: exerciseProvider.isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ExerciseSelectionScreen(), // <-- SIN const
                            ),
                          );
                        },
                  isPrimary: true,
                ),
                const SizedBox(height: 16),

                _buildMenuButton(
                  context,
                  icon: Icons.settings,
                  title: '⚙️ Configuración',
                  description: 'Ajusta tempo, volumen y preferencias',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildMenuButton(
                  context,
                  icon: Icons.info,
                  title: 'ℹ️ Acerca de',
                  description: 'Información y arquitectura del sistema',
                  onPressed: () {
                    _showAboutDialog(context);
                  },
                ),

                if (exercises.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildStatsWidget(context, exerciseProvider.getStats()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: isPrimary ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isPrimary
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: isPrimary
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isPrimary
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: isPrimary
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsWidget(BuildContext context, ExerciseStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            '${stats.completedExercises}/${stats.totalExercises}',
            'Completados',
            Icons.check_circle,
          ),
          _buildStatItem(
            context,
            '${stats.favoriteCount}',
            'Favoritos',
            Icons.favorite,
          ),
          _buildStatItem(
            context,
            '${stats.completionRate.toStringAsFixed(0)}%',
            'Progreso',
            Icons.trending_up,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
        ),
      ],
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acerca de Entrenador Musical'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Versión: 1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Características principales:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureBullet('✓ Motor temporal basado en TPQN 480'),
              _buildFeatureBullet('✓ Sistema de anacrusa automático'),
              _buildFeatureBullet('✓ Soporte completo para MusicXML'),
              _buildFeatureBullet('✓ Visualización SMuFL profesional'),
              _buildFeatureBullet('✓ Metrónomo con acentos'),
              _buildFeatureBullet('✓ Análisis de precisión en tiempo real'),
              const SizedBox(height: 16),
              const Text(
                'Arquitectura modular:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildFeatureBullet('• Musical Engine (Lógica pura)'),
              _buildFeatureBullet('• Visual Engine (SMuFL)'),
              _buildFeatureBullet('• Game Logic (Orquestación)'),
              _buildFeatureBullet('• MusicXML Parser (Importación)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
