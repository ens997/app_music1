// lib/core/globals.dart
import 'package:flutter/material.dart';

const double _minNoteSpacingScale = 0.75;
const double _maxNoteSpacingScale = 1.0;
final ValueNotifier<double> noteSpacingScale =
    ValueNotifier<double>(_maxNoteSpacingScale);

const double _minMusicStartOffsetScale = 0.0;
const double _maxMusicStartOffsetScale = 1.0;
final ValueNotifier<double> musicStartOffsetScale =
    ValueNotifier<double>(_minMusicStartOffsetScale);