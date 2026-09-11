import 'dart:typed_data';
import 'dart:math' as math;

/// Generador de clicks de metronomo con percusion seca.
class MetronomeClickGenerator {
  /// Genera un click de metronomo (golpe seco y suave, sin nota).
  /// isAccent: true para click de acento, false para click normal.
  /// Retorna un Uint8List con el audio WAV del click.
  static Uint8List buildClick({required bool isAccent, int sampleRate = 44100}) {
    final durationMs = isAccent ? 70 : 50;
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

    // Knock-style click: short inharmonic resonances with minimal attack noise.
    final attackSamples = (sampleRate * 0.0010).round(); // 1.0ms
    final bodyDecay = isAccent ? 42.0 : 48.0;
    final tapDecay = isAccent ? 96.0 : 112.0;
    final highDecay = isAccent ? 150.0 : 170.0;
    final lowMode = isAccent ? 176.0 : 154.0;
    final woodMode = isAccent ? 319.0 : 287.0;
    final knockMode = isAccent ? 673.0 : 607.0;
    final shellMode = isAccent ? 1237.0 : 1093.0;

    final random = math.Random(12345);

    for (int i = 0; i < totalSamples; i++) {
      double env;
      if (i < attackSamples) {
        env = i / attackSamples;
      } else {
        final decayTime = (i - attackSamples) / sampleRate;
        env = math.exp(-bodyDecay * decayTime);
      }

      final t = i / sampleRate;
      final low = math.sin(2.0 * math.pi * lowMode * t) *
          math.exp(-bodyDecay * t) *
          0.26;
      final wood = math.sin((2.0 * math.pi * woodMode * t) + 0.71) *
          math.exp(-tapDecay * t) *
          0.34;
      final knock = math.sin((2.0 * math.pi * knockMode * t) + 1.83) *
          math.exp(-tapDecay * 1.35 * t) *
          0.28;
      final shell = math.sin((2.0 * math.pi * shellMode * t) + 2.47) *
          math.exp(-highDecay * t) *
          0.12;
      final attackNoise = (random.nextDouble() * 2.0 - 1.0) *
          math.exp(-230.0 * t) *
          0.025;

      final sample = ((low + wood) * env) + knock + shell + attackNoise;
      final amplitude = isAccent ? 0.82 : 0.56;
      final intSample =
          (sample * amplitude * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + (i * 2), intSample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
