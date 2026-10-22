import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/flute_audio_sample_generator.dart';

void main() {
  test('generates a mono 16-bit WAV sample with a valid data length', () {
    final sample = FluteAudioSampleGenerator.buildSample(
      pitch: 'A4',
      sampleRate: 8000,
      durationMs: 100,
    );
    final header = ByteData.sublistView(sample);

    expect(String.fromCharCodes(sample.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(sample.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 8000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 1600);
    expect(sample.length, 44 + 1600);
    expect(sample.sublist(44).any((byte) => byte != 0), isTrue);
  });

  test('generated samples are deterministic and depend on pitch', () {
    final firstA4 = FluteAudioSampleGenerator.buildSample(
      pitch: 'A4',
      sampleRate: 8000,
      durationMs: 100,
    );
    final secondA4 = FluteAudioSampleGenerator.buildSample(
      pitch: 'A4',
      sampleRate: 8000,
      durationMs: 100,
    );
    final c5 = FluteAudioSampleGenerator.buildSample(
      pitch: 'C5',
      sampleRate: 8000,
      durationMs: 100,
    );

    expect(firstA4, secondA4);
    expect(firstA4, isNot(c5));
  });

  test('rejects invalid pitches and sample dimensions', () {
    expect(
      () => FluteAudioSampleGenerator.buildSample(pitch: 'invalid'),
      throwsArgumentError,
    );
    expect(
      () => FluteAudioSampleGenerator.buildSample(pitch: 'A4', sampleRate: 0),
      throwsArgumentError,
    );
    expect(
      () => FluteAudioSampleGenerator.buildSample(pitch: 'C-2'),
      throwsArgumentError,
    );
    expect(
      () => FluteAudioSampleGenerator.buildSample(pitch: 'A4', durationMs: 0),
      throwsArgumentError,
    );
  });
}
