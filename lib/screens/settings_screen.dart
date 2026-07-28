// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../core/globals.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _spacingScale;
  late double _startOffsetScale;

  @override
  void initState() {
    super.initState();
    _spacingScale = noteSpacingScale.value;
    _startOffsetScale = musicStartOffsetScale.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Calibración de Espaciado Horizontal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ajusta la distancia entre notas. 100% (derecha) es el valor actual por defecto y 75% (izquierda) es el mínimo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('75%'),
                  Expanded(
                    child: Slider(
                      min: 0.75,
                      max: 1.0,
                      divisions: 25,
                      value: _spacingScale,
                      label: '${(_spacingScale * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _spacingScale = value;
                        });
                        noteSpacingScale.value = value;
                      },
                    ),
                  ),
                  const Text('100%'),
                ],
              ),
              Text(
                'Valor actual: ${(_spacingScale * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 18),
              const Text(
                'Calibración del Inicio de la Música',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Mínimo (izquierda): posición actual. Máximo (derecha): mitad de pantalla.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Actual'),
                  Expanded(
                    child: Slider(
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      value: _startOffsetScale,
                      label: '${(_startOffsetScale * 100).round()}%',
                      onChanged: (value) {
                        setState(() {
                          _startOffsetScale = value;
                        });
                        musicStartOffsetScale.value = value;
                      },
                    ),
                  ),
                  const Text('Mitad'),
                ],
              ),
              Text(
                'Desplazamiento de inicio: ${(_startOffsetScale * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}