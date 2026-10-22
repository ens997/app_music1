import 'dart:math' as math;
import 'dart:typed_data';

import '../core/musical_engine/pitch_utils.dart';
import 'pcm_wav_builder.dart';

class ViolinAudioSampleGenerator {
  static const int lowestMidiNote = 55;
  static const int highestMidiNote = 100;

  static Uint8List buildSample({
    required String pitch,
    int sampleRate = 22050,
    int durationMs = 1200,
  }) {
    final midiNote = PitchUtils.toMidi(pitch);
    if (midiNote == null ||
        midiNote < lowestMidiNote ||
        midiNote > highestMidiNote) {
      throw ArgumentError.value(
        pitch,
        'pitch',
        'Violin samples are supported from G3 to E7',
      );
    }
    if (sampleRate < 8000) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (durationMs <= 0) {
      throw ArgumentError.value(durationMs, 'durationMs');
    }

    final frequency = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0).toDouble();
    final attackSamples = (sampleRate * 0.11).round();
    final releaseSamples = (sampleRate * 0.16).round();
    final random = math.Random(midiNote * 37);
    final nyquistFrequency = sampleRate / 2;

    return PcmWavBuilder.buildMono16Bit(
      sampleRate: sampleRate,
      durationMs: durationMs,
      sampleAt: (sampleIndex, totalSamples) {
        final elapsedSeconds = sampleIndex / sampleRate;
        final remainingSamples = totalSamples - sampleIndex;
        final attack = math.min(1.0, sampleIndex / attackSamples);
        final release = math.min(1.0, remainingSamples / releaseSamples);
        final envelope = math.min(attack, release);
        final vibratoFade = math.min(1.0, elapsedSeconds / 0.28);
        final vibrato =
            math.sin(2.0 * math.pi * 5.2 * elapsedSeconds) *
            0.004 *
            vibratoFade;
        final phase =
            2.0 * math.pi * frequency * elapsedSeconds * (1.0 + vibrato);

        var tone = 0.0;
        for (var harmonic = 1; harmonic <= 8; harmonic++) {
          if (frequency * harmonic >= nyquistFrequency) break;
          final amplitude = 1.0 / math.pow(harmonic, 1.16);
          final bowingPulse = math.sin(
            2.0 * math.pi * 4.1 * elapsedSeconds + harmonic * 0.7,
          );
          tone +=
              math.sin(phase * harmonic + harmonic * 0.13) *
              amplitude *
              (1.0 + 0.025 * bowingPulse);
        }

        final breathAndBowNoise =
            (random.nextDouble() * 2.0 - 1.0) * 0.009 * envelope;
        return (tone / 1.65) * envelope * 0.52 + breathAndBowNoise;
      },
    );
  }
}
