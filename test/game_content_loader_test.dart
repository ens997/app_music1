import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_music1/core/core.dart';
import 'package:app_music1/services/exercise_loader_service.dart';
import 'package:app_music1/services/game_content_loader.dart';

const _musicXml = '''
<score-partwise>
  <part id="P1">
    <measure number="1">
      <note><rest/><duration>1</duration></note>
    </measure>
  </part>
</score-partwise>
''';

Exercise _exercise() => Exercise(
  id: 'inicial-1',
  title: 'Ejercicio 1',
  description: 'Ejercicio de prueba',
  fileName: '1.musicxml',
  assetPath: 'assets/exercises/inicial/1.musicxml',
  difficulty: Difficulty.initial,
  type: ExerciseType.rhythmTraining,
  composer: 'Prueba',
);

class _FakeExerciseLoader extends ExerciseLoaderService {
  final Exercise? exercise;

  _FakeExerciseLoader(this.exercise);

  @override
  Future<Exercise?> loadAndGetFirstExercise() async => exercise;
}

void main() {
  test('preloaded catalog content uses its asset and display metadata', () {
    final exercise = _exercise();
    final loaded = GameContentLoader().loadPreloadedContent(
      _musicXml,
      exercise: exercise,
      fileName: exercise.fileName,
    );

    expect(loaded.score.notes.single.isRest, isTrue);
    expect(loaded.audioTrackPath, exercise.assetPath);
    expect(loaded.status, '🎵 Ejercicio 1 - Prueba');
  });

  test('preloaded file name resolves to its accompaniment asset path', () {
    final loaded = GameContentLoader().loadPreloadedContent(
      _musicXml,
      fileName: '1.musicxml',
    );

    expect(loaded.audioTrackPath, 'musicxml_preload/1.musicxml');
    expect(loaded.status, isEmpty);
  });

  test(
    'local file loads through the parser and retains its audio path',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'game_content_loader_test',
      );
      final file = File(
        '${tempDirectory.path}${Platform.pathSeparator}score.musicxml',
      );
      await file.writeAsString(_musicXml);

      try {
        final loaded = await GameContentLoader().loadFile(file.path);

        expect(loaded.score.notes.single.isRest, isTrue);
        expect(loaded.audioTrackPath, file.path);
        expect(loaded.status, isEmpty);
      } finally {
        await tempDirectory.delete(recursive: true);
      }
    },
  );

  test('first exercise loads its asset and metadata', () async {
    final exercise = _exercise();
    String? requestedAsset;
    final loader = GameContentLoader(
      exerciseLoader: _FakeExerciseLoader(exercise),
      loadAsset: (assetPath) async {
        requestedAsset = assetPath;
        return _musicXml;
      },
    );

    final loaded = await loader.loadFirstExercise();

    expect(requestedAsset, exercise.assetPath);
    expect(loaded?.score.notes.single.isRest, isTrue);
    expect(loaded?.audioTrackPath, exercise.assetPath);
    expect(loaded?.status, '🎵 Ejercicio 1 - Prueba');
  });

  test('first exercise returns null when the catalog is empty', () async {
    var assetRequested = false;
    final loader = GameContentLoader(
      exerciseLoader: _FakeExerciseLoader(null),
      loadAsset: (_) async {
        assetRequested = true;
        return _musicXml;
      },
    );

    expect(await loader.loadFirstExercise(), isNull);
    expect(assetRequested, isFalse);
  });
}
