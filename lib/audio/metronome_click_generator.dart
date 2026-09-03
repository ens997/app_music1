import 'dart:typed_data';
import 'dart:math' as math;

/// Generador de clicks de metrónomo con percusión pura y seca.
/// Crea ondas WAV sintéticas de golpes sin ningún carácter tonal.
class MetronomeClickGenerator {
  /// Genera un click de metrónomo (golpe seco y suave, sin nota).
  /// isAccent: true para click de acento (más fuerte), false para click normal.
  /// Retorna un Uint8List con el audio WAV del click.
  static Uint8List buildClick({required bool isAccent, int sampleRate = 44100}) {
    // Duración del click: golpe muy corto
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

    // Encabezado WAV
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

    // Generar click percusivo puro (sin contenido tonal)
    // Attack ultra-rápido (< 0.5ms) + decay rápido
    final attackSamples = (sampleRate * 0.0003).round(); // 0.3ms
    final decayRateFast = isAccent ? 35.0 : 40.0; // Decay exponencial rápido

    final random = math.Random(12345); // Seed fijo para consistencia

    for (int i = 0; i < totalSamples; i++) {
      // Envolvente: attack lineal rápido + decay exponencial
      double env;
      if (i < attackSamples) {
        // Attack: sube muy rápido
        env = (i / attackSamples);
      } else {
        // Decay: cae exponencialmente (golpe seco)
        final decayTime = (i - attackSamples) / sampleRate;
        env = math.exp(-decayRateFast * decayTime);
      }

      // Generar ruido pseudo-aleatorio (no tonal)
      // Mezclar componentes de diferentes rangos de frecuencia
      final noise1 = (random.nextDouble() * 2.0 - 1.0); // Ruido blanco puro
      final noise2 = _generateFilteredNoise(i, sampleRate, random, 3000.0); // Componente mid-high

      // Combinar ruidos para golpe seco
      final sample = (noise1 * 0.6 + noise2 * 0.4) * env;

      // Amplitud final: acento más fuerte
      final amplitude = isAccent ? 0.65 : 0.42;
      final intSample = (sample * amplitude * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(44 + (i * 2), intSample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }

  /// Genera ruido filtrado simple usando recursión de primer orden.
  /// Crea un componente de ruido más controlado sin tonalidad.
  static double _generateFilteredNoise(
    int sampleIndex,
    int sampleRate,
    math.Random random,
    double filterFreq,
  ) {
    // Simple low-pass filter simulado mediante promedios
    // Esto reduce la aleatoriedad pura a ruido más "suave"
    final alpha = 2.0 * math.pi * filterFreq / sampleRate;
    final clampedAlpha = alpha.clamp(0.0, 1.0);

    // Generar ruido y aplicar factor de suavizado
    final rawNoise = random.nextDouble() * 2.0 - 1.0;
    return rawNoise * clampedAlpha;
  }
}
