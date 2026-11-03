import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path_provider/path_provider.dart';

import '../core/musical_engine/pitch_utils.dart';
import 'audio_service_lifecycle.dart';
import 'instrument_audio_output.dart';
import 'instrument_sample_generator.dart';
import 'instrument_type.dart';
import 'metronome_audio_output.dart';
import 'metronome_click_generator.dart';

abstract class SampledInstrumentAudioService
    implements SustainedInstrumentAudioOutput, MetronomeAudioOutput {
  SampledInstrumentAudioService({
    required InstrumentType instrument,
    required List<String> supportedNotes,
    required Duration sustainAttack,
    required Duration sustainLoopDuration,
  }) : _instrument = instrument,
       _supportedNotes = List.unmodifiable(supportedNotes),
       _sustainAttack = sustainAttack,
       _sustainLoopDuration = sustainLoopDuration;

  final InstrumentType _instrument;
  final List<String> _supportedNotes;
  final Duration _sustainAttack;
  final Duration _sustainLoopDuration;
  final AudioServiceLifecycle _lifecycle = AudioServiceLifecycle();
  final Map<String, AudioSource> _noteSources = {};
  final Map<String, AudioSource> _sustainNoteSources = {};
  final Map<int, SoundHandle> _heldVoices = {};
  int _nextVoiceId = 0;
  SoLoud? _soloud;
  AudioSource? _accentClickSource;
  AudioSource? _normalClickSource;

  @override
  AudioServiceState get state => _lifecycle.state;

  @override
  Future<void> initialize() {
    return _lifecycle.initialize(_initializeResources);
  }

  Future<bool> _initializeResources() async {
    try {
      final soloud = SoLoud.instance;
      _soloud = soloud;
      await soloud.init();

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final cacheDirectory = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}'
        '${_instrument.name}_audio_cache',
      );
      if (!await cacheDirectory.exists()) {
        await cacheDirectory.create(recursive: true);
      }

      final missingNotes = <String>[];
      final missingSustainNotes = <String>[];
      for (final note in _supportedNotes) {
        if (!await _sampleFile(cacheDirectory, note).exists()) {
          missingNotes.add(note);
        }
        if (!await _sustainSampleFile(cacheDirectory, note).exists()) {
          missingSustainNotes.add(note);
        }
      }

      if (missingNotes.isNotEmpty) {
        final samples = await generateInstrumentSampleBatch(
          _instrument,
          missingNotes,
        );
        for (final entry in samples.entries) {
          await _sampleFile(
            cacheDirectory,
            entry.key,
          ).writeAsBytes(entry.value, flush: true);
        }
      }
      if (missingSustainNotes.isNotEmpty) {
        final sustainSamples = await generateInstrumentSampleBatch(
          _instrument,
          missingSustainNotes,
          sustained: true,
        );
        for (final entry in sustainSamples.entries) {
          await _sustainSampleFile(
            cacheDirectory,
            entry.key,
          ).writeAsBytes(entry.value, flush: true);
        }
      }

      final accentClickFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'metronome_accent.wav',
      );
      final normalClickFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}'
        'metronome_normal.wav',
      );
      if (!await accentClickFile.exists()) {
        await accentClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: true),
          flush: true,
        );
      }
      if (!await normalClickFile.exists()) {
        await normalClickFile.writeAsBytes(
          MetronomeClickGenerator.buildClick(isAccent: false),
          flush: true,
        );
      }

      for (final note in _supportedNotes) {
        _noteSources[note] = await soloud.loadFile(
          _sampleFile(cacheDirectory, note).path,
        );
        _sustainNoteSources[note] = await soloud.loadFile(
          _sustainSampleFile(cacheDirectory, note).path,
        );
      }
      _accentClickSource = await soloud.loadFile(accentClickFile.path);
      _normalClickSource = await soloud.loadFile(normalClickFile.path);
      return true;
    } on ArgumentError catch (error) {
      if (!error.message.toString().contains('flutter_soloud_plugin')) {
        await _disposeResources();
        rethrow;
      }
      debugPrint('El plugin de audio no está disponible: ${error.message}');
      _soloud = null;
      return false;
    } catch (_) {
      await _disposeResources();
      rethrow;
    }
  }

  File _sampleFile(Directory directory, String note) {
    return File('${directory.path}${Platform.pathSeparator}$note.wav');
  }

  File _sustainSampleFile(Directory directory, String note) {
    return File(
      '${directory.path}${Platform.pathSeparator}${note}_sustain_loop_v2_'
      '${_sustainLoopDuration.inMilliseconds}ms.wav',
    );
  }

  @override
  Future<void> playNote(String pitch, {double volume = 0.85}) async {
    if (state == AudioServiceState.idle) await initialize();
    if (state != AudioServiceState.ready) return;

    final canonicalPitch = PitchUtils.normalize(pitch);
    final source = _noteSources[canonicalPitch];
    final soloud = _soloud;
    if (source == null || soloud == null) {
      debugPrint('No hay sample de ${_instrument.displayName} para $pitch');
      return;
    }
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  @override
  Future<int?> noteOn(String pitch, {double volume = 0.85}) async {
    if (state == AudioServiceState.idle) await initialize();
    if (state != AudioServiceState.ready) return null;

    final canonicalPitch = PitchUtils.normalize(pitch);
    final source = _sustainNoteSources[canonicalPitch];
    final soloud = _soloud;
    if (source == null || soloud == null) {
      debugPrint(
        'No hay sample sostenido de ${_instrument.displayName} para $pitch',
      );
      return null;
    }

    final voice = await soloud.play(source, volume: 0, looping: true);
    soloud.fadeVolume(voice, volume.clamp(0.0, 1.0), _sustainAttack);
    final voiceId = ++_nextVoiceId;
    _heldVoices[voiceId] = voice;
    return voiceId;
  }

  @override
  Future<void> noteOff(int voiceId) async {
    final voice = _heldVoices.remove(voiceId);
    final soloud = _soloud;
    if (voice == null || soloud == null || !soloud.isInitialized) return;

    const releaseDuration = Duration(milliseconds: 120);
    if (soloud.getIsValidVoiceHandle(voice)) {
      soloud.fadeVolume(voice, 0, releaseDuration);
      await Future<void>.delayed(releaseDuration);
      if (soloud.isInitialized && soloud.getIsValidVoiceHandle(voice)) {
        await soloud.stop(voice);
      }
    }
  }

  @override
  Future<void> playMetronomeClick({
    required bool isAccent,
    double volume = 0.85,
  }) async {
    if (state == AudioServiceState.idle) await initialize();
    if (state != AudioServiceState.ready) return;

    final source = isAccent ? _accentClickSource : _normalClickSource;
    final soloud = _soloud;
    if (source == null || soloud == null) return;
    await soloud.play(source, volume: volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> dispose() => _lifecycle.dispose(_disposeResources);

  Future<void> _disposeResources() async {
    final soloud = _soloud;
    if (soloud != null) {
      if (soloud.isInitialized) {
        for (final voice in _heldVoices.values) {
          if (soloud.getIsValidVoiceHandle(voice)) {
            await soloud.stop(voice);
          }
        }
      }
      _heldVoices.clear();
      for (final source in _noteSources.values) {
        await soloud.disposeSource(source);
      }
      for (final source in _sustainNoteSources.values) {
        await soloud.disposeSource(source);
      }
      if (_accentClickSource != null) {
        await soloud.disposeSource(_accentClickSource!);
      }
      if (_normalClickSource != null) {
        await soloud.disposeSource(_normalClickSource!);
      }
      soloud.deinit();
    }
    _noteSources.clear();
    _sustainNoteSources.clear();
    _accentClickSource = null;
    _normalClickSource = null;
    _soloud = null;
  }
}
