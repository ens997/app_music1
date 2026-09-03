import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'metronome_click_generator.dart';

/// Servicio de audio optimizado para piano.
/// - Genera ondas en Isolate (no bloquea UI).
/// - Cachea las ondas en disco para reutilización.
class PianoAudioService {
  static const List<String> _supportedNotes = [
    'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
    'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
    'C6', 'C#6', 'D6', 'D#6', 'E6', 'F6', 'F#6', 'G6', 'G#6', 'A6', 'A#6', 'B6',
  ];

  final List<AudioPlayer> _players = [];
  final Map<String, Uint8List> _noteWaveBytes = {};
  int _playerIndex = 0;
  bool _initialized = false;
  bool _isGenerating = false;
  Completer<void>? _initializationCompleter;

  /// Inicializa el servicio (generación asíncrona en Isolate).
  Future<void> initialize({bool forceRegenerate = false}) async {
    if (_initialized) return;
    if (_isGenerating) {
      await _initializationCompleter?.future;
      return;
    }

    _isGenerating = true;
    _initializationCompleter = Completer<void>();

    try {
      // Crear pool de reproductores
      for (int i = 0; i < 8; i++) {
        _players.add(AudioPlayer());
      }

      // Intentar cargar desde caché de disco
      final cacheDir = await getApplicationDocumentsDirectory();
      final cacheFolder = Directory('${cacheDir.path}/piano_audio_cache');
      if (!await cacheFolder.exists()) {
        await cacheFolder.create(recursive: true);
      }

      // Cargar notas desde caché o generarlas
      final notesToGenerate = <String>[];
      for (final note in _supportedNotes) {
        final file = File('${cacheFolder.path}/$note.wav');
        if (await file.exists() && !forceRegenerate) {
          // Cargar desde disco
          final bytes = await file.readAsBytes();
          _noteWaveBytes[note] = Uint8List.fromList(bytes);
        } else {
          notesToGenerate.add(note);
        }
      }

      // Generar notas faltantes en Isolate
      if (notesToGenerate.isNotEmpty) {
        final generatedBytes = await compute(_generateWavesInBackground, notesToGenerate);
        for (final entry in generatedBytes.entries) {
          final note = entry.key;
          final bytes = entry.value;
          _noteWaveBytes[note] = bytes;

          // Guardar en disco para futuras ejecuciones
          final file = File('${cacheFolder.path}/$note.wav');
          await file.writeAsBytes(bytes);
        }
      }

      _initialized = true;
      _isGenerating = false;
      _initializationCompleter?.complete();
    } catch (e) {
      _isGenerating = false;
      _initializationCompleter?.completeError(e);
      rethrow;
    }
  }

  /// Reproduce un click de metrónomo (percusión suave).
  /// isAccent: true para click de acento (más fuerte), false para click normal.
  Future<void> playMetronomeClick({required bool isAccent, double volume = 0.85}) async {
    if (!_initialized) {
      await initialize();
    }

    final bytes = MetronomeClickGenerator.buildClick(isAccent: isAccent);
    final player = _players[_playerIndex];
    _playerIndex = (_playerIndex + 1) % _players.length;

    await player.play(
      BytesSource(bytes),
      volume: volume.clamp(0.0, 1.0),
    );
  }

  /// Reproduce una nota (pool de reproductores).
  Future<void> playNote(String note, {double volume = 0.85}) async {
    if (!_initialized) {
      await initialize();
    }
    final bytes = _noteWaveBytes[note];
    if (bytes == null) return;

    final player = _players[_playerIndex];
    _playerIndex = (_playerIndex + 1) % _players.length;

    await player.play(
      BytesSource(bytes),
      volume: volume.clamp(0.0, 1.0),
    );
  }

  /// Libera recursos.
  Future<void> dispose() async {
    for (final player in _players) {
      await player.dispose();
    }
    _players.clear();
    _noteWaveBytes.clear();
    _initialized = false;
    _isGenerating = false;
  }

  /// Limpia la caché de disco (para forzar regeneración).
  static Future<void> clearCache() async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final cacheFolder = Directory('${cacheDir.path}/piano_audio_cache');
    if (await cacheFolder.exists()) {
      await cacheFolder.delete(recursive: true);
    }
  }
}

// ============================================================
// FUNCIONES TOP-LEVEL PARA ISOLATE
// ============================================================

/// Genera un mapa de notas -> bytes WAV en un Isolate.
/// Recibe una lista de nombres de notas y retorna un Map<String, Uint8List>.
Future<Map<String, Uint8List>> _generateWavesInBackground(List<String> notes) async {
  final result = <String, Uint8List>{};
  for (final note in notes) {
    final frequency = _noteToFrequency(note);
    final durationMs = _durationForNote(note);
    final bytes = _buildSineWaveWav(
      note: note,
      frequencyHz: frequency,
      durationMs: durationMs,
    );
    result[note] = bytes;
  }
  return result;
}

// ============================================================
// FUNCIONES DE GENERACIÓN DE ONDA (PURO CÁLCULO, SIN DEPENDENCIAS DE FLUTTER)
// ============================================================

double _noteToFrequency(String note) {
  final match = RegExp(r'^([A-G])(#?)(\d)$').firstMatch(note);
  if (match == null) return 440.0;

  final name = match.group(1)!;
  final isSharp = match.group(2) == '#';
  final octave = int.parse(match.group(3)!);

  const semitoneBase = {
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  final midi = (octave + 1) * 12 + semitoneBase[name]! + (isSharp ? 1 : 0);
  return 440.0 * math.pow(2.0, (midi - 69) / 12.0).toDouble();
}

int _durationForNote(String note) {
  final match = RegExp(r'\d$').firstMatch(note);
  final octave = int.tryParse(match?.group(0) ?? '5') ?? 5;

  switch (octave) {
    case 4:
      return 900;
    case 5:
      return 720;
    case 6:
      return 560;
    default:
      return 680;
  }
}

Uint8List _buildSineWaveWav({
  required String note,
  required double frequencyHz,
  required int durationMs,
  int sampleRate = 44100,
}) {
  final totalSamples = (sampleRate * durationMs / 1000).round();
  final byteRate = sampleRate * 2;
  final dataSize = totalSamples * 2;
  final buffer = ByteData(44 + dataSize);

  void writeString(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      buffer.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  buffer.setUint32(16, 16, Endian.little);
  buffer.setUint16(20, 1, Endian.little);
  buffer.setUint16(22, 1, Endian.little);
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, byteRate, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  buffer.setUint32(40, dataSize, Endian.little);

  final twoPiF = 2.0 * math.pi * frequencyHz;
  final octave = int.tryParse(RegExp(r'\d$').firstMatch(note)?.group(0) ?? '5') ?? 5;
  final attackSamples = (sampleRate * 0.0035).round();
  final decaySamples = (sampleRate * (octave <= 4 ? 0.16 : 0.11)).round();
  final releaseSamples = (sampleRate * (octave <= 4 ? 0.22 : 0.14)).round();
  final sustainLevel = octave <= 4 ? 0.22 : 0.16;
  final fundamentalDecay = octave <= 4 ? 2.8 : 3.6;
  final overtoneDecay = octave <= 4 ? 5.2 : 6.8;
  final phase2 = 0.31;
  final phase3 = 1.07;
  final phase4 = 2.21;

  for (int i = 0; i < totalSamples; i++) {
    final t = i / sampleRate;
    final env = _envelopeForSample(
      sampleIndex: i,
      totalSamples: totalSamples,
      attackSamples: attackSamples,
      decaySamples: decaySamples,
      releaseSamples: releaseSamples,
      sustainLevel: sustainLevel,
    );

    final fundamental = math.sin(twoPiF * t) * math.exp(-fundamentalDecay * t);
    final second = math.sin((twoPiF * 2.0 * t) + phase2) * math.exp(-overtoneDecay * t);
    final third = math.sin((twoPiF * 3.0 * t) + phase3) * math.exp(-(overtoneDecay + 1.2) * t);
    final fourth = math.sin((twoPiF * 4.0 * t) + phase4) * math.exp(-(overtoneDecay + 2.1) * t);
    final detune = math.sin((twoPiF * 1.003 * t) + 0.17) * math.exp(-(fundamentalDecay + 0.9) * t);
    final hammerNoise = (math.sin(2.0 * math.pi * 6400 * t) + math.sin(2.0 * math.pi * 5100 * t)) *
        math.exp(-38 * t);

    final sample = (
          (fundamental * 0.72) +
          (second * 0.18) +
          (third * 0.08) +
          (fourth * 0.04) +
          (detune * 0.06) +
          (hammerNoise * 0.018)
        ) *
        env *
        0.62;
    final intSample = (sample * 32767).round().clamp(-32768, 32767);
    buffer.setInt16(44 + (i * 2), intSample, Endian.little);
  }

  return buffer.buffer.asUint8List();
}

double _envelopeForSample({
  required int sampleIndex,
  required int totalSamples,
  required int attackSamples,
  required int decaySamples,
  required int releaseSamples,
  required double sustainLevel,
}) {
  if (sampleIndex < attackSamples) {
    final attackProgress = sampleIndex / attackSamples;
    return math.pow(attackProgress, 0.6).toDouble();
  }

  final decayEnd = attackSamples + decaySamples;
  if (sampleIndex < decayEnd) {
    final decayProgress = (sampleIndex - attackSamples) / decaySamples;
    return 1.0 - ((1.0 - sustainLevel) * math.pow(decayProgress, 0.85).toDouble());
  }

  final releaseStart = totalSamples - releaseSamples;
  if (sampleIndex < releaseStart) {
    return sustainLevel;
  }

  final releaseProgress = (sampleIndex - releaseStart) / releaseSamples;
  return sustainLevel * (1.0 - math.pow(releaseProgress, 1.4).toDouble()).clamp(0.0, 1.0);
}