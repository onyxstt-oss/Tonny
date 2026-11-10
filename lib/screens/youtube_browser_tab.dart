import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  late final WebViewController _controller;
  bool _isLoadingPage = true;
  bool _isAnalyzingVideo = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoadingPage = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoadingPage = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.youtube.com'));
  }

  Future<void> _onDownloadPressed() async {
    if (_isAnalyzingVideo) return;

    final currentUrl = await _controller.currentUrl() ?? '';
    final isVideo = currentUrl.contains('watch?v=') ||
        currentUrl.contains('youtu.be/') ||
        currentUrl.contains('/shorts/');

    if (!isVideo) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Primero entra a un video o canción de YouTube para elegir el formato de descarga.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAnalyzingVideo = true);

    try {
      final result = await widget.appState.analyzeYoutubeUrl(currentUrl);
      final Video video = result['video'];
      final List<DownloadFormatOption> options = result['options'];

      if (!mounted) return;
      _showFormatSelectorModal(video, options);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se pudieron obtener los formatos: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzingVideo = false);
    }
  }

  void _showFormatSelectorModal(Video video, List<DownloadFormatOption> options) {
    showModalBottomSheet(
      context: context,
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
                // Cabecera con miniatura y título del video
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        video.thumbnails.mediumResUrl,
                        width: 72,
                        height: 54,
                        fit: BoxFit.cover,
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
                Flexible(
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181A),
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'YouTube Navegador',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                await _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => _controller.loadRequest(Uri.parse('https://m.youtube.com')),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoadingPage)
            const LinearProgressIndicator(
              color: Colors.pinkAccent,
              backgroundColor: Colors.transparent,
            ),

          // Botón flotante "Descargar" con selector de MP3 / M4A / MP4 y calidades
          Positioned(
            right: 16,
            bottom: 18,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              elevation: 8,
              onPressed: _onDownloadPressed,
              icon: _isAnalyzingVideo
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(
                _isAnalyzingVideo ? 'Analizando...' : 'Descargar',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
