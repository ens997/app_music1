import 'dart:typed_data';

class PcmWavBuilder {
  static Uint8List buildMono16Bit({
    required int sampleRate,
    required int durationMs,
    required double Function(int sampleIndex, int totalSamples) sampleAt,
  }) {
    _validateSampleRate(sampleRate);
    if (durationMs <= 0) throw ArgumentError.value(durationMs, 'durationMs');
    final sampleCount = (sampleRate * durationMs / 1000).round();
    return _buildMono16Bit(
      sampleRate: sampleRate,
      sampleCount: sampleCount,
      sampleAt: sampleAt,
    );
  }

  static Uint8List buildMono16BitFrames({
    required int sampleRate,
    required int sampleCount,
    required double Function(int sampleIndex, int totalSamples) sampleAt,
  }) {
    _validateSampleRate(sampleRate);
    if (sampleCount <= 0) {
      throw ArgumentError.value(sampleCount, 'sampleCount');
    }
    return _buildMono16Bit(
      sampleRate: sampleRate,
      sampleCount: sampleCount,
      sampleAt: sampleAt,
    );
  }

  static void _validateSampleRate(int sampleRate) {
    if (sampleRate < 8000) throw ArgumentError.value(sampleRate, 'sampleRate');
  }

  static Uint8List _buildMono16Bit({
    required int sampleRate,
    required int sampleCount,
    required double Function(int sampleIndex, int totalSamples) sampleAt,
  }) {
    const channels = 1;
    const bitsPerSample = 16;
    final dataSize = sampleCount * channels * bitsPerSample ~/ 8;
    final buffer = ByteData(44 + dataSize);

    void writeString(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        buffer.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    buffer.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    writeString(36, 'data');
    buffer.setUint32(40, dataSize, Endian.little);

    for (var sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
      final value = sampleAt(sampleIndex, sampleCount);
      final pcmValue = (value * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + sampleIndex * 2, pcmValue, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
