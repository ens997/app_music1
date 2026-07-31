import 'package:flutter/material.dart';
import '../core/models/note_model.dart';

/// Almacena una nota con su posición precalculada en el pentagrama.
class NoteLayout {
  final NoteModel note;
  final Offset position; // posición X,Y en píxeles (coordenadas absolutas)

  NoteLayout(this.note, this.position);
}