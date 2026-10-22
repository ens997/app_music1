import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/audio/metronome_click_generator.dart';

void main() {
  test('builds a valid mono PCM WAV for a normal click', () {
    const sampleRate = 8000;
    final bytes = MetronomeClickGenerator.buildClick(
      isAccent: false,
      sampleRate: sampleRate,
    );
    final data = ByteData.sublistView(bytes);
    const durationMs = 50;
    final totalSamples = sampleRate * durationMs ~/ 1000;
    final dataSize = totalSamples * 2;

    expect(bytes.length, 44 + dataSize);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    expect(data.getUint32(4, Endian.little), 36 + dataSize);
    expect(data.getUint32(16, Endian.little), 16);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), sampleRate);
    expect(data.getUint32(28, Endian.little), sampleRate * 2);
    expect(data.getUint16(32, Endian.little), 2);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), dataSize);
  });

  test('builds a longer and louder accent click', () {
    const sampleRate = 8000;
    final normal = MetronomeClickGenerator.buildClick(
      isAccent: false,
      sampleRate: sampleRate,
    );
    final accent = MetronomeClickGenerator.buildClick(
      isAccent: true,
      sampleRate: sampleRate,
    );
    final normalData = ByteData.sublistView(normal);
    final accentData = ByteData.sublistView(accent);

    expect(accent.length, 44 + (sampleRate * 70 ~/ 1000) * 2);
    expect(accent.length, greaterThan(normal.length));

    var normalPeak = 0;
    var accentPeak = 0;
    for (var offset = 44; offset < normal.length; offset += 2) {
      normalPeak = math.max(
        normalPeak,
        normalData.getInt16(offset, Endian.little).abs(),
      );
    }
    for (var offset = 44; offset < accent.length; offset += 2) {
      accentPeak = math.max(
        accentPeak,
        accentData.getInt16(offset, Endian.little).abs(),
      );
    }

    expect(normalPeak, greaterThan(0));
    expect(accentPeak, greaterThan(normalPeak));
  });

  test('is deterministic for the same click parameters', () {
    final first = MetronomeClickGenerator.buildClick(
      isAccent: true,
      sampleRate: 11025,
    );
    final second = MetronomeClickGenerator.buildClick(
      isAccent: true,
      sampleRate: 11025,
    );

    expect(first, orderedEquals(second));
  });
}
