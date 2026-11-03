import 'dart:math' as math;
import 'dart:typed_data';

import 'pcm_wav_builder.dart';

class LoopingToneSampleGenerator {
  static Uint8List build({
    required double frequency,
    required int sampleRate,
    required int loopDurationMs,
    required List<double> harmonics,
    double amplitude = 0.64,
  }) {
    if (sampleRate < 8000) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (frequency <= 0 || frequency >= sampleRate / 2) {
      throw ArgumentError.value(frequency, 'frequency');
    }
    if (loopDurationMs <= 0) {
      throw ArgumentError.value(loopDurationMs, 'loopDurationMs');
    }

    final audibleHarmonics = [
      for (var index = 0; index < harmonics.length; index++)
        if (frequency * (index + 1) < sampleRate / 2) harmonics[index],
    ];
    final loopSampleCount = (sampleRate * loopDurationMs / 1000).round();
    final loopCycles = (frequency * loopSampleCount / sampleRate).round();
    final actualFrequency = sampleRate * loopCycles / loopSampleCount;
    final harmonicNormalization = audibleHarmonics.fold<double>(
      0,
      (sum, weight) => sum + weight.abs(),
    );

    return PcmWavBuilder.buildMono16BitFrames(
      sampleRate: sampleRate,
      sampleCount: loopSampleCount,
      sampleAt: (sampleIndex, _) {
        final loopPhase =
            2.0 * math.pi * actualFrequency * sampleIndex / sampleRate;
        var tone = 0.0;
        for (var harmonic = 0; harmonic < audibleHarmonics.length; harmonic++) {
          tone +=
              math.sin(loopPhase * (harmonic + 1)) * audibleHarmonics[harmonic];
        }
        return tone / harmonicNormalization * amplitude;
      },
    );
  }
}
