import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/app_state.dart';

class FileManagerTab extends StatefulWidget {
  final AppState appState;

  const FileManagerTab({super.key, required this.appState});

  @override
  State<FileManagerTab> createState() => _FileManagerTabState();
}

class _FileManagerTabState extends State<FileManagerTab> {
  String _selectedFilter = 'ALL'; // 'ALL', 'AUDIO', 'VIDEO'

  String _formatBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        final totalBytes = appState.library.fold<int>(
          0,
          (sum, item) => sum + item.fileSizeBytes,
        );

        final filteredFiles = appState.library.where((item) {
          if (_selectedFilter == 'AUDIO') return !item.isVideo;
          if (_selectedFilter == 'VIDEO') return item.isVideo;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF111113),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111113),
            elevation: 0,
            title: const Text(
              'Gestor de Archivos y Descargas',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              // Tarjeta de resumen de memoria del teléfono
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.pinkAccent.withOpacity(0.25),
                      Colors.deepPurpleAccent.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sd_storage_rounded, color: Colors.pinkAccent, size: 38),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Memoria del Teléfono (/Music/AppleMusicYT)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${appState.library.length} archivo(s) guardados • ${_formatBytes(totalBytes)} usados',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Sección de Descargas en Curso
              if (appState.activeDownloads.isNotEmpty) ...[
                const Text(
                  'DESCARGAS RECIENTES / EN CURSO',
                  style: TextStyle(
                    color: Colors.pinkAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                ...appState.activeDownloads.map(
                  (task) => Card(
                    color: const Color(0xFF1E1E22),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  task.format,
                                  style: const TextStyle(
                                    color: Colors.pinkAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: task.progress,
                            color: Colors.pinkAccent,
                            backgroundColor: Colors.white12,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                task.status,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              Text(
                                '${(task.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Filtros de archivos guardados
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ARCHIVOS EN DISPOSITIVO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ALL', label: Text('Todos')),
                      ButtonSegment(value: 'AUDIO', label: Text('MP3/M4A')),
                      ButtonSegment(value: 'VIDEO', label: Text('MP4')),
                    ],
                    selected: {_selectedFilter},
                    onSelectionChanged: (s) {
                      setState(() => _selectedFilter = s.first);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (filteredFiles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No hay archivos guardados en esta categoría.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              else
                ...filteredFiles.map(
                  (item) => Card(
                    color: const Color(0xFF1C1C20),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.isVideo
                            ? Colors.blueAccent.withOpacity(0.2)
                            : Colors.pinkAccent.withOpacity(0.2),
                        child: Text(
                          item.format,
                          style: TextStyle(
                            color: item.isVideo ? Colors.blueAccent : Colors.pinkAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${_formatBytes(item.fileSizeBytes)} • ${item.filePath}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                            tooltip: 'Renombrar',
                            onPressed: () => _showRenameDialog(context, appState, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                            tooltip: 'Borrar del teléfono',
                            onPressed: () => appState.deleteMediaItem(item),
                          ),
                        ],
                      ),
                      onTap: () => appState.playItem(item, contextList: filteredFiles),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(
    BuildContext context,
    AppState appState,
    MediaItemModel item,
  ) {
    final titleCtrl = TextEditingController(text: item.title);
    final artistCtrl = TextEditingController(text: item.artist);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242428),
        title: const Text('Editar metadatos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Título',
                labelStyle: TextStyle(color: Colors.pinkAccent),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: artistCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Artista / Canal',
                labelStyle: TextStyle(color: Colors.pinkAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              appState.renameMediaItem(item, titleCtrl.text, artistCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
