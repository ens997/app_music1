import 'dart:math' as math;
import 'dart:typed_data';

import '../core/musical_engine/pitch_utils.dart';
import 'looping_tone_sample_generator.dart';
import 'pcm_wav_builder.dart';

class FluteAudioSampleGenerator {
  static const int sustainAttackMs = 35;
  static const int sustainLoopDurationMs = 1000;

  static Uint8List buildSample({
    required String pitch,
    int sampleRate = 22050,
    int durationMs = 800,
  }) {
    final midiNote = _validatedMidiNote(pitch);
    _validateSampleDimensions(sampleRate, durationMs);

    final frequency = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0).toDouble();
    if (frequency >= sampleRate / 2) {
      throw ArgumentError.value(
        pitch,
        'pitch',
        'Exceeds the sample Nyquist frequency',
      );
    }
    final attackSamples = (sampleRate * 0.035).round();
    final releaseSamples = (sampleRate * 0.12).round();
    final random = math.Random(midiNote);

    return PcmWavBuilder.buildMono16Bit(
      sampleRate: sampleRate,
      durationMs: durationMs,
      sampleAt: (sampleIndex, totalSamples) {
        final elapsedSeconds = sampleIndex / sampleRate;
        final remainingSamples = totalSamples - sampleIndex;
        final attack = math.min(1.0, sampleIndex / attackSamples);
        final release = math.min(1.0, remainingSamples / releaseSamples);
        final envelope = math.min(attack, release);
        final phase = 2.0 * math.pi * frequency * elapsedSeconds;
        final fundamental = math.sin(phase) * 0.78;
        final secondHarmonic = math.sin(phase * 2.0 + 0.08) * 0.15;
        final thirdHarmonic = math.sin(phase * 3.0 + 0.16) * 0.045;
        final fourthHarmonic = math.sin(phase * 4.0 + 0.24) * 0.012;
        final breathNoise =
            (random.nextDouble() * 2.0 - 1.0) * 0.012 * envelope;
        final value =
            ((fundamental + secondHarmonic + thirdHarmonic + fourthHarmonic) *
                envelope *
                0.64) +
            breathNoise;
        return value;
      },
    );
  }

  static Uint8List buildSustainSample({
    required String pitch,
    int sampleRate = 22050,
  }) {
    final midiNote = _validatedMidiNote(pitch);
    final frequency = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0).toDouble();
    return LoopingToneSampleGenerator.build(
      frequency: frequency,
      sampleRate: sampleRate,
      loopDurationMs: sustainLoopDurationMs,
      harmonics: const [0.78, 0.15, 0.045, 0.012],
    );
  }

  static int _validatedMidiNote(String pitch) {
    final midiNote = PitchUtils.toMidi(pitch);
    if (midiNote == null || midiNote < 0 || midiNote > 127) {
      throw ArgumentError.value(pitch, 'pitch');
    }
    return midiNote;
  }

  static void _validateSampleDimensions(int sampleRate, int durationMs) {
    if (sampleRate < 8000) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (durationMs <= 0) {
      throw ArgumentError.value(durationMs, 'durationMs');
    }
  }
}
