import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/violin_audio_sample_generator.dart';

void main() {
  test('generates a valid non-silent mono WAV sample', () {
    final sample = ViolinAudioSampleGenerator.buildSample(
      pitch: 'A4',
      sampleRate: 8000,
      durationMs: 200,
    );
    final header = ByteData.sublistView(sample);

    expect(String.fromCharCodes(sample.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(sample.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 8000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 3200);
    expect(sample.length, 44 + 3200);
    expect(sample.sublist(44).any((byte) => byte != 0), isTrue);
  });

  test('generated sample is deterministic', () {
    final first = ViolinAudioSampleGenerator.buildSample(
      pitch: 'D5',
      sampleRate: 8000,
      durationMs: 100,
    );
    final second = ViolinAudioSampleGenerator.buildSample(
      pitch: 'D5',
      sampleRate: 8000,
      durationMs: 100,
    );

    expect(first, second);
  });

  test('supports the violin range and rejects pitches outside it', () {
    expect(
      ViolinAudioSampleGenerator.buildSample(
        pitch: 'G3',
        sampleRate: 8000,
        durationMs: 50,
      ),
      isNotEmpty,
    );
    expect(
      ViolinAudioSampleGenerator.buildSample(
        pitch: 'E7',
        sampleRate: 22050,
        durationMs: 50,
      ),
      isNotEmpty,
    );
    expect(
      () => ViolinAudioSampleGenerator.buildSample(pitch: 'F3'),
      throwsArgumentError,
    );
    expect(
      () => ViolinAudioSampleGenerator.buildSample(pitch: 'F7'),
      throwsArgumentError,
    );
  });
}
