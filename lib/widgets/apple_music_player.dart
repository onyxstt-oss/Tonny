import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/media_item.dart';
import '../services/app_state.dart';

String formatDuration(Duration d) {
  final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$mins:$secs';
}

class AppleMusicMiniPlayer extends StatelessWidget {
  final AppState appState;

  const AppleMusicMiniPlayer({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final track = appState.currentTrack;
    if (track == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AppleMusicFullPlayerSheet(appState: appState),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF252528).withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                track.thumbnailUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  color: Colors.pinkAccent.withOpacity(0.3),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                appState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
              onPressed: appState.togglePlayPause,
            ),
            IconButton(
              icon: const Icon(
                Icons.fast_forward_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: appState.skipNext,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class AppleMusicFullPlayerSheet extends StatefulWidget {
  final AppState appState;

  const AppleMusicFullPlayerSheet({super.key, required this.appState});

  @override
  State<AppleMusicFullPlayerSheet> createState() =>
      _AppleMusicFullPlayerSheetState();
}

class _AppleMusicFullPlayerSheetState extends State<AppleMusicFullPlayerSheet> {
  bool _showQueueView = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final appState = widget.appState;
        final track = appState.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final posSec = appState.position.inSeconds.toDouble();
        final durSec = appState.duration.inSeconds.toDouble();
        final maxSlider = durSec > 0 ? durSec : 1.0;
        final curSlider = posSec.clamp(0.0, maxSlider);
        final remaining = appState.duration - appState.position;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.94,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo dinámico con la carátula desenfocada estilo Apple Music
                Image.network(
                  track.thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1C1C1E)),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container(
                    color: Colors.black.withOpacity(0.62),
                  ),
                ),

                // Contenido principal del reproductor
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                    child: Column(
                      children: [
                        // Barra superior (indicador para deslizar hacia abajo)
                        Container(
                          width: 42,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),

                        // Área central dinámica: Portada / Letra / Cola "A continuación"
                        Expanded(
                          child: _showQueueView
                              ? _buildUpNextQueue(appState)
                              : appState.showLyrics
                                  ? _buildLyricsSection(context, appState, track)
                                  : _buildArtworkSection(track, appState.isPlaying),
                        ),

                        const SizedBox(height: 18),

                        // Título de la canción y artista
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${track.artist} • ${track.format}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
                              ),
                              tooltip: 'Editar letra',
                              onPressed: () => _showEditLyricsDialog(context, appState, track),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Barra de progreso estilo Apple Music
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.25),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: curSlider,
                            min: 0.0,
                            max: maxSlider,
                            onChanged: (val) {
                              appState.seekTo(Duration(seconds: val.round()));
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatDuration(appState.position),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '-${formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Controles principales de reproducción
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              iconSize: 42,
                              icon: const Icon(Icons.fast_rewind_rounded, color: Colors.white),
                              onPressed: appState.skipPrevious,
                            ),
                            IconButton(
                              iconSize: 64,
                              icon: Icon(
                                appState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: appState.togglePlayPause,
                            ),
                            IconButton(
                              iconSize: 42,
                              icon: const Icon(Icons.fast_forward_rounded, color: Colors.white),
                              onPressed: appState.skipNext,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Barra inferior estilo Apple Music (Letra, Aleatorio, Repetir, Cola "A continuación")
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Botón de Letra (Lyrics)
                            IconButton(
                              tooltip: 'Visualizar Letra',
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: appState.showLyrics && !_showQueueView
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.format_quote_rounded,
                                  color: appState.showLyrics && !_showQueueView
                                      ? Colors.black
                                      : Colors.white.withOpacity(0.8),
                                  size: 24,
                                ),
                              ),
                              onPressed: () {
                                setState(() => _showQueueView = false);
                                appState.toggleLyricsView();
                              },
                            ),

                            // Botón Shuffle (Aleatorio)
                            IconButton(
                              tooltip: 'Aleatorio',
                              icon: Icon(
                                Icons.shuffle_rounded,
                                color: appState.shuffleEnabled
                                    ? Colors.pinkAccent
                                    : Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                              onPressed: appState.toggleShuffle,
                            ),

                            // Botón Repeat (Repetir)
                            IconButton(
                              tooltip: 'Repetir',
                              icon: Icon(
                                appState.loopMode == LoopMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: appState.loopMode != LoopMode.off
                                    ? Colors.pinkAccent
                                    : Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                              onPressed: appState.cycleLoopMode,
                            ),

                            // Botón Cola "A continuación" (Up Next)
                            IconButton(
                              tooltip: 'Cola A continuación',
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _showQueueView ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.queue_music_rounded,
                                  color: _showQueueView
                                      ? Colors.black
                                      : Colors.white.withOpacity(0.8),
                                  size: 24,
                                ),
                              ),
                              onPressed: () {
                                setState(() => _showQueueView = !_showQueueView);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtworkSection(MediaItemModel track, bool isPlaying) {
    return Center(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.86,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                track.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white10,
                  child: const Icon(Icons.music_note_rounded, size: 110, color: Colors.white54),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsSection(
    BuildContext context,
    AppState appState,
    MediaItemModel track,
  ) {
    final parsedLines = track.parseSynchronizedLyrics();

    if (parsedLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, color: Colors.white54, size: 60),
            const SizedBox(height: 14),
            const Text(
              'No se encontró letra automática para esta canción.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Pegar o escribir letra manualmente'),
              onPressed: () => _showEditLyricsDialog(context, appState, track),
            ),
          ],
        ),
      );
    }

    // Determinar línea activa si la letra está sincronizada con marcas de tiempo
    int activeLineIndex = -1;
    for (int i = 0; i < parsedLines.length; i++) {
      if (parsedLines[i].timestamp > Duration.zero &&
          appState.position >= parsedLines[i].timestamp) {
        activeLineIndex = i;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LETRA DE LA CANCIÓN',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1.4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: parsedLines.length,
            itemBuilder: (context, idx) {
              final line = parsedLines[idx];
              final isCurrent = idx == activeLineIndex;
              return GestureDetector(
                onTap: () {
                  if (line.timestamp > Duration.zero) {
                    appState.seekTo(line.timestamp);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    line.text,
                    style: TextStyle(
                      color: isCurrent || activeLineIndex == -1
                          ? Colors.white
                          : Colors.white.withOpacity(0.42),
                      fontSize: isCurrent ? 24 : 20,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpNextQueue(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A CONTINUACIÓN EN LA COLA',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: appState.playQueue.length,
            itemBuilder: (context, index) {
              final item = appState.playQueue[index];
              final isCurrent = index == appState.currentQueueIndex;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.thumbnailUrl,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 46,
                      height: 46,
                      color: Colors.white12,
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? Colors.pinkAccent : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  item.artist,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                  onPressed: () => appState.removeFromQueue(index),
                ),
                onTap: () => appState.playFromQueueIndex(index),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditLyricsDialog(
    BuildContext context,
    AppState appState,
    MediaItemModel track,
  ) {
    final controller = TextEditingController(text: track.lyrics ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252528),
        title: const Text('Letra de la canción', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Pega aquí la letra de la canción (normal o con tiempos [00:15.00])...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              appState.updateTrackLyrics(track, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Guardar Letra', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
