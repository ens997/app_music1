import 'dart:typed_data';

class PcmWavBuilder {
  static Uint8List buildMono16Bit({
    required int sampleRate,
    required int durationMs,
    required double Function(int sampleIndex, int totalSamples) sampleAt,
  }) {
    if (sampleRate < 8000) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }
    if (durationMs <= 0) {
      throw ArgumentError.value(durationMs, 'durationMs');
    }

    const channels = 1;
    const bitsPerSample = 16;
    final totalSamples = (sampleRate * durationMs / 1000).round();
    final dataSize = totalSamples * channels * bitsPerSample ~/ 8;
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

    for (var sampleIndex = 0; sampleIndex < totalSamples; sampleIndex++) {
      final value = sampleAt(sampleIndex, totalSamples);
      final pcmValue = (value * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + sampleIndex * 2, pcmValue, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
