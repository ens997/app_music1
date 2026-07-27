import 'package:flutter/material.dart';

/// Widget que muestra un teclado de piano interactivo.
/// Emite la nota presionada a través del callback [onNotePressed].
class PianoInput extends StatelessWidget {
  /// Notas disponibles por defecto (C4 a B6)
  static const List<String> defaultNotes = [
    'C4', 'C#4', 'D4', 'D#4', 'E4', 'F4', 'F#4', 'G4', 'G#4', 'A4', 'A#4', 'B4',
    'C5', 'C#5', 'D5', 'D#5', 'E5', 'F5', 'F#5', 'G5', 'G#5', 'A5', 'A#5', 'B5',
    'C6', 'C#6', 'D6', 'D#6', 'E6', 'F6', 'F#6', 'G6', 'G#6', 'A6', 'A#6', 'B6',
  ];

  final bool enabled;
  final ValueChanged<String> onNotePressed;
  final double height;
  final List<String> notes;
  final Color whiteKeyColor;
  final Color blackKeyColor;
  final Color borderColor;

  const PianoInput({
    Key? key,
    required this.enabled,
    required this.onNotePressed,
    this.height = 120,
    this.notes = defaultNotes,
    this.whiteKeyColor = Colors.white,
    this.blackKeyColor = const Color(0xFF111318),
    this.borderColor = const Color(0xFFD9DEE8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final whiteNotes = notes.where((n) => !_isBlack(n)).toList();
    final blackNotes = notes.where(_isBlack).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Stack(
            children: [
              // Teclas blancas
              Row(
                children: whiteNotes.map((note) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: SizedBox(
                      width: 44,
                      child: ElevatedButton(
                        onPressed: enabled ? () => onNotePressed(note) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: whiteKeyColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.only(bottom: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFCFD6E3)),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            note,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Teclas negras (superpuestas)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !enabled,
                  child: Row(
                    children: List.generate(whiteNotes.length, (index) {
                      final note = whiteNotes[index];
                      final nextNote = index + 1 < whiteNotes.length
                          ? whiteNotes[index + 1]
                          : null;
                      final semitoneBetween = _semitone(nextNote) - _semitone(note);
                      final hasBlack = nextNote != null && semitoneBetween == 2;

                      return SizedBox(
                        width: 48,
                        child: Stack(
                          children: [
                            if (hasBlack)
                              Positioned(
                                right: -10,
                                top: 0,
                                child: GestureDetector(
                                  onTap: enabled
                                      ? () {
                                          final black = _sharpBetween(note, nextNote);
                                          if (black != null) onNotePressed(black);
                                        }
                                      : null,
                                  child: Container(
                                    width: 20,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      color: enabled
                                          ? blackKeyColor
                                          : const Color(0xFF5A5F6B),
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isBlack(String note) => note.contains('#');

  int _semitone(String? pitch) {
    if (pitch == null) return 0;
    final m = RegExp(r'^([A-G])(\d)$').firstMatch(pitch);
    if (m == null) return 0;
    const map = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    return (int.parse(m.group(2)!) * 12) + map[m.group(1)]!;
  }

  String? _sharpBetween(String left, String? right) {
    if (right == null) return null;
    final m = RegExp(r'^([A-G])(\d)$').firstMatch(left);
    if (m == null) return null;
    final note = m.group(1)!;
    final octave = m.group(2)!;
    if (note == 'E' || note == 'B') return null;
    return '$note#$octave';
  }
}