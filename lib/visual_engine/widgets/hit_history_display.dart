import 'package:flutter/material.dart';
import '../../core/models/enumerations.dart';

/// Muestra una secuencia de círculos coloreados que representan el historial
/// de aciertos/fallos del usuario.
class HitHistoryDisplay extends StatelessWidget {
  final List<HitQuality> history;
  final double dotSize;
  final double spacing;
  final int maxItems;

  const HitHistoryDisplay({
    Key? key,
    required this.history,
    this.dotSize = 10,
    this.spacing = 3,
    this.maxItems = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mostrar solo los últimos 'maxItems'
    final displayList = history.length > maxItems
        ? history.sublist(history.length - maxItems)
        : history;

    return Wrap(
      spacing: spacing,
      children: displayList.map((quality) {
        return Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: Color(quality.colorValue),
            shape: BoxShape.circle,
          ),
        );
      }).toList(),
    );
  }
}