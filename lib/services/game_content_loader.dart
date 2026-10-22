import 'package:flutter/services.dart';

import '../core/core.dart';
import '../parsers/musicxml_parser.dart';
import 'exercise_loader_service.dart';

typedef AssetTextLoader = Future<String> Function(String assetPath);

class GameContent {
  final MusicScore score;
  final String? audioTrackPath;
  final String status;

  const GameContent({
    required this.score,
    required this.audioTrackPath,
    required this.status,
  });
}

class GameContentLoader {
  final ExerciseLoaderService _exerciseLoader;
  final AssetTextLoader _loadAsset;

  GameContentLoader({
    ExerciseLoaderService? exerciseLoader,
    AssetTextLoader? loadAsset,
  }) : _exerciseLoader = exerciseLoader ?? ExerciseLoaderService(),
       _loadAsset =
           loadAsset ?? ((assetPath) => rootBundle.loadString(assetPath));

  GameContent loadPreloadedContent(
    String content, {
    Exercise? exercise,
    String? fileName,
  }) {
    return GameContent(
      score: MusicXMLParser.parse(content),
      audioTrackPath:
          exercise?.assetPath ??
          (fileName == null ? null : 'musicxml_preload/$fileName'),
      status: exercise == null
          ? ''
          : '🎵 ${exercise.title} - ${exercise.composer}',
    );
  }

  Future<GameContent> loadFile(String filePath) async {
    return GameContent(
      score: await MusicXMLParser.parseFile(filePath),
      audioTrackPath: filePath,
      status: '',
    );
  }

  Future<GameContent?> loadFirstExercise() async {
    final exercise = await _exerciseLoader.loadAndGetFirstExercise();
    if (exercise == null) return null;

    final content = await _loadAsset(exercise.assetPath);
    return GameContent(
      score: MusicXMLParser.parse(content),
      audioTrackPath: exercise.assetPath,
      status: '🎵 ${exercise.title} - ${exercise.composer}',
    );
  }
}
