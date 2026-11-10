import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_item.dart';
import '../services/app_state.dart';

class YoutubeBrowserTab extends StatefulWidget {
  final AppState appState;

  const YoutubeBrowserTab({super.key, required this.appState});

  @override
  State<YoutubeBrowserTab> createState() => _YoutubeBrowserTabState();
}

class _YoutubeBrowserTabState extends State<YoutubeBrowserTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Video> _videos = [];
  bool _isLoading = false;
  String? _analyzingVideoId;
  String _selectedCategory = 'Tendencias Música';

  final List<String> _categories = [
    'Tendencias Música',
    'La Santa Grifa',
    'Rap Mexicano',
    'Éxitos Latinos',
    'Corridos Tumbados',
    'Reggaetón',
    'Rock en Español',
  ];

  @override
  void initState() {
    super.initState();
    _performSearch(_selectedCategory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final results = await widget.appState.searchYoutubeVideos(query);
      if (mounted) {
        setState(() {
          _videos = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error al buscar en YouTube. Verifica tu conexión.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _onDownloadVideoPressed(Video video) async {
    if (_analyzingVideoId != null) return;
    setState(() => _analyzingVideoId = video.id.value);

    try {
      final options = await widget.appState.getFormatsForVideo(video);
      if (!mounted) return;
      _showFormatSelectorModal(video, options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ El servidor bloqueó la consulta de este video. Intenta con otro.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _analyzingVideoId = null);
    }
  }

  String _formatVideoDuration(Duration? d) {
    if (d == null) return 'EN VIVO';
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$mins:$secs';
    }
    return '$mins:$secs';
  }

  void _showFormatSelectorModal(
    Video video,
    List<DownloadFormatOption> options,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        video.thumbnails.mediumResUrl,
                        width: 76,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 76,
                          height: 56,
                          color: Colors.white12,
                          child: const Icon(Icons.music_note, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            video.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const Text(
                  'ELIGE FORMATO Y CALIDAD DE DESCARGA:',
                  style: TextStyle(
                    color: Colors.pinkAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, idx) {
                      final opt = options[idx];
                      final isVideo = opt.format == 'MP4';
                      return Card(
                        color: const Color(0xFF2C2C2E),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isVideo
                                ? Colors.blueAccent.withOpacity(0.2)
                                : Colors.pinkAccent.withOpacity(0.2),
                            child: Icon(
                              isVideo ? Icons.videocam_rounded : Icons.audiotrack_rounded,
                              color: isVideo ? Colors.blueAccent : Colors.pinkAccent,
                            ),
                          ),
                          title: Text(
                            opt.qualityLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isVideo
                                ? 'Guardar video MP4 en el teléfono'
                                : 'Guardar audio con letra automática en biblioteca',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.download_rounded, color: Colors.white),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.appState.startDownload(video: video, option: opt);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⬇️ Descargando "${video.title}" en ${opt.format}...'),
                                backgroundColor: Colors.pinkAccent,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111113),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161619),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text(
              'YouTube Música y Videos',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de búsqueda nativa de YouTube (sin anuncios ni cierres de WebView)
          Container(
            color: const Color(0xFF161619),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Busca una canción, artista o pega un link de YouTube...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.pinkAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.pinkAccent),
                      onPressed: () => _performSearch(_searchController.text),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF232327),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Chips de categorías rápidas
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) {
                      final cat = _categories[idx];
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: Colors.pinkAccent,
                        backgroundColor: const Color(0xFF232327),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        onSelected: (_) {
                          setState(() => _selectedCategory = cat);
                          _searchController.text = cat;
                          _performSearch(cat);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Lista de resultados de YouTube con botón directo "Descargar"
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  )
                : _videos.isEmpty
                    ? const Center(
                        child: Text(
                          'Busca cualquier canción o artista arriba.',
                          style: TextStyle(color: Colors.white54, fontSize: 15),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          final isAnalyzingThis = _analyzingVideoId == video.id.value;

                          return Card(
                            color: const Color(0xFF1B1B1F),
                            margin: const EdgeInsets.symmetric(vertical: 7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Miniatura grande con duración
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            video.thumbnails.highResUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.white10,
                                              child: const Icon(
                                                Icons.music_video_rounded,
                                                color: Colors.white54,
                                                size: 56,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _formatVideoDuration(video.duration),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Título, canal y botón "Descargar"
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              video.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              video.author,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.pinkAccent,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 11,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: () => _onDownloadVideoPressed(video),
                                        icon: isAnalyzingThis
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.download_rounded, size: 20),
                                        label: Text(
                                          isAnalyzingThis ? 'Cargando...' : 'Descargar',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
