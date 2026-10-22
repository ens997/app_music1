// lib/screens/settings_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../audio/instrument_audio_registry.dart';
import '../audio/instrument_type.dart';
import '../core/globals.dart';
import '../services/instrument_settings_service.dart';
import '../services/latency_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _spacingScale;
  late double _startOffsetScale;
  late InstrumentType _selectedInstrument;
  bool _isSavingInstrument = false;
  int _instrumentDropdownRevision = 0;

  @override
  void initState() {
    super.initState();
    _spacingScale = noteSpacingScale.value;
    _startOffsetScale = musicStartOffsetScale.value;
    _selectedInstrument = InstrumentSettingsService.selectedInstrument.value;
  }

  Future<void> _selectInstrument(InstrumentType? instrument) async {
    if (instrument == null || _isSavingInstrument) return;
    setState(() => _isSavingInstrument = true);

    try {
      await InstrumentSettingsService.select(instrument);
      if (mounted) setState(() => _selectedInstrument = instrument);
    } catch (error) {
      if (mounted) {
        setState(() => _instrumentDropdownRevision++);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el instrumento: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingInstrument = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Instrumento',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<InstrumentType>(
                  key: ValueKey(_instrumentDropdownRevision),
                  initialValue: _selectedInstrument,
                  decoration: const InputDecoration(
                    labelText: 'Instrumento para las notas',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final instrument
                        in InstrumentAudioRegistry.availableInstruments)
                      DropdownMenuItem(
                        value: instrument,
                        child: Text(instrument.displayName),
                      ),
                  ],
                  onChanged: _isSavingInstrument ? null : _selectInstrument,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Piano, flauta y violín están disponibles. Los sonidos de flauta y violín son sintéticos y se cargan al seleccionar el instrumento. La selección se aplica a las partidas nuevas.',
                  textAlign: TextAlign.center,
                ),
                if (_isSavingInstrument)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 18),
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
                const Divider(height: 1),
                const SizedBox(height: 18),
                const Text(
                  'Calibración de sincronización',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _LatencySlider(
                  label: 'Latencia de audio',
                  value: audioLatencyMs.value,
                  onChanged: (value) {
                    setState(() => audioLatencyMs.value = value);
                    unawaited(LatencySettingsService.save());
                  },
                ),
                _LatencySlider(
                  label: 'Latencia de entrada',
                  value: inputLatencyMs.value,
                  onChanged: (value) {
                    setState(() => inputLatencyMs.value = value);
                    unawaited(LatencySettingsService.save());
                  },
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
      ),
    );
  }
}

class _LatencySlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _LatencySlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$label: ${value}ms'),
        Slider(
          min: 0,
          max: 300,
          divisions: 30,
          value: value.toDouble(),
          label: '${value}ms',
          onChanged: (next) => onChanged(next.round()),
        ),
      ],
    );
  }
}
