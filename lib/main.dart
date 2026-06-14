import 'package:flutter/material.dart';

import 'screens/screens.dart';

void main() {
  runApp(const MusicTrainingApp());
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Entrenador Musical Pro'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icono
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

                // Título
                Text(
                  'Bienvenido al Entrenador Musical',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Sistema avanzado de entrenamiento musical con soporte para MusicXML, '
                  'metrónomo automático y análisis de precisión rítmica.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[400],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Botones principales
                _buildMenuButton(
                  context,
                  icon: Icons.play_arrow,
                  title: 'Iniciar Juego',
                  description: 'Comienza un nuevo ejercicio',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildMenuButton(
                  context,
                  icon: Icons.folder_open,
                  title: 'Elegir nivel',
                  description: 'Importa un archivo de notación musical',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const GameScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                _buildMenuButton(
                  context,
                  icon: Icons.settings,
                  title: 'Configuración',
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
                  title: 'Acerca de',
                  description: 'Información y arquitectura del sistema',
                  onPressed: () {
                    _showAboutDialog(context);
                  },
                ),
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
    required VoidCallback onPressed,
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
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
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
