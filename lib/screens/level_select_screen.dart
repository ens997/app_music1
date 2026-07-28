// lib/screens/level_select_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/musicxml_preload_service.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({Key? key}) : super(key: key);

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final MusicXmlPreloadService _preloadService = MusicXmlPreloadService();
  late Future<List<PreloadedMusicXmlFile>> _filesFuture;
  PreloadedMusicXmlFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    _filesFuture = _loadAvailableLevels();
  }

  Future<List<PreloadedMusicXmlFile>> _loadAvailableLevels() async {
    try {
      final discoveredFiles = await _preloadService.discover();
      if (discoveredFiles.isNotEmpty) {
        return discoveredFiles;
      }

      return await _loadLevelsFromAssets();
    } catch (e) {
      return await _loadLevelsFromAssets();
    }
  }

  Future<List<PreloadedMusicXmlFile>> _loadLevelsFromAssets() async {
    try {
      final manifestJson =
          await rootBundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      final musicxmlFiles = manifest.keys
          .where((String key) =>
              key.startsWith('musicxml_preload/') &&
              (key.endsWith('.xml') || key.endsWith('.musicxml')))
          .toList();

      musicxmlFiles.sort();

      return musicxmlFiles
          .map((path) {
            final fileName = path.split('/').last;
            return PreloadedMusicXmlFile(
              name: fileName,
              path: path,
            );
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Nivel'),
      ),
      body: FutureBuilder<List<PreloadedMusicXmlFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Buscando archivos MusicXML...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data ?? [];

          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No se encontraron archivos MusicXML\n\nColoca archivos .xml o .musicxml\nen la carpeta musicxml_preload/',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filesFuture = _loadAvailableLevels();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        selected: _selectedFile == file,
                        selectedTileColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.14),
                        leading: const Icon(Icons.music_note),
                        title: Text(file.name),
                        trailing: _selectedFile == file
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedFile = file;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _selectedFile == null
                          ? 'Seleccione un nivel para activar el botón Iniciar.'
                          : 'Nivel seleccionado: ${_selectedFile!.name}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar'),
                      onPressed: _selectedFile == null
                          ? null
                          : () async {
                              try {
                                final file = _selectedFile!;
                                if (file.path.startsWith('musicxml_preload/')) {
                                  final content =
                                      await rootBundle.loadString(file.path);
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        preloadedContent: content,
                                        fileName: file.name,
                                      ),
                                    ),
                                  );
                                } else {
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GameScreen(
                                        preloadedFilePath: file.path,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error al iniciar nivel: $e'),
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}