/// Representación de armadura (Key Signature) musical
class KeySignature {
  final int fifths; // Número de sostenidos (positivo) o bemoles (negativo)
  final String mode; // 'major', 'minor', etc. (por defecto 'major')

  const KeySignature({
    required this.fifths,
    this.mode = 'major',
  });

  /// Retorna true si es armadura de sostenidos
  bool get isSharp => fifths > 0;

  /// Retorna true si es armadura de bemoles
  bool get isFlat => fifths < 0;

  /// Número absoluto de alteraciones
  int get alterationCount => fifths.abs();

  /// Lista de posiciones para las alteraciones (basado en clave de Sol)
  /// Retorna lista de offsets en líneas/espacios (0 = línea de Sol, 1 = espacio arriba, etc.)
  List<int> get alterationPositions {
    if (fifths == 0) return [];

    final positions = <int>[];
    if (isSharp) {
      // Sostenidos: F#, C#, G#, D#, A#, E#, B#
      const sharpPositions = [3, 0, 4, 1, 5, 2, 6]; // offsets desde línea de Sol
      for (int i = 0; i < fifths; i++) {
        positions.add(sharpPositions[i]);
      }
    } else {
      // Bemoles: Bb, Eb, Ab, Db, Gb, Cb, Fb
      const flatPositions = [2, 5, 1, 4, 0, 3, 6]; // offsets desde línea de Sol
      for (int i = 0; i < -fifths; i++) {
        positions.add(flatPositions[i]);
      }
    }
    return positions;
  }

  /// Representación en string
  @override
  String toString() {
    if (fifths == 0) return 'C major';
    final alteration = isSharp ? 'sharp' : 'flat';
    final count = alterationCount;
    return '$count $alteration${count > 1 ? 's' : ''}';
  }
}