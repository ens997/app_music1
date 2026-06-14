import 'dart:io';
import 'dart:io';

class PreloadedMusicXmlFile {
  final String name;
  final String path;

  const PreloadedMusicXmlFile({
    required this.name,
    required this.path,
  });
}

class MusicXmlPreloadService {
  static const folderName = 'musicxml_preload';
  static const supportedExtensions = ['.xml', '.musicxml'];

  Future<List<PreloadedMusicXmlFile>> discover() async {
    final discovered = <PreloadedMusicXmlFile>[];
    final seenPaths = <String>{};

    for (final directory in _candidateDirectories()) {
      if (!await directory.exists()) continue;

      final entries = await directory
          .list(followLinks: false)
          .where((entry) => entry is File && _isSupported(entry.path))
          .cast<File>()
          .toList();

      entries.sort((a, b) => _fileName(a.path).compareTo(_fileName(b.path)));

      for (final file in entries) {
        final normalizedPath = file.absolute.path.toLowerCase();
        if (!seenPaths.add(normalizedPath)) continue;

        discovered.add(
          PreloadedMusicXmlFile(
            name: _fileName(file.path),
            path: file.path,
          ),
        );
      }
    }

    return discovered;
  }

  List<String> candidateFolderPaths() {
    return _candidateDirectories().map((directory) => directory.path).toList();
  }

  List<Directory> _candidateDirectories() {
    final currentFolder = Directory('${Directory.current.path}${Platform.pathSeparator}$folderName');
    final executableFolder = File(Platform.resolvedExecutable).parent;
    final executablePreloadFolder = Directory(
      '${executableFolder.path}${Platform.pathSeparator}$folderName',
    );

    if (currentFolder.absolute.path.toLowerCase() ==
        executablePreloadFolder.absolute.path.toLowerCase()) {
      return [currentFolder];
    }

    return [currentFolder, executablePreloadFolder];
  }

  bool _isSupported(String path) {
    final lower = path.toLowerCase();
    return supportedExtensions.any(lower.endsWith);
  }

  String _fileName(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }
}

