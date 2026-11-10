import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/media_item.dart';

class AppState extends ChangeNotifier {
  final AudioPlayer audioPlayer = AudioPlayer();
  final Dio _dio = Dio();

  List<MediaItemModel> library = [];
  List<PlaylistModel> playlists = [];
  List<MediaItemModel> playQueue = [];
  List<ActiveDownloadTask> activeDownloads = [];

  int currentQueueIndex = -1;
  bool isPlaying = false;
  bool shuffleEnabled = false;
  LoopMode loopMode = LoopMode.off;
  bool showLyrics = false;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  MediaItemModel? get currentTrack =>
      (currentQueueIndex >= 0 && currentQueueIndex < playQueue.length)
          ? playQueue[currentQueueIndex]
          : null;

  AppState() {
    _initAudioPlayer();
    _loadPersistedData();
  }

  Future<void> _initAudioPlayer() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    audioPlayer.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
      }
      notifyListeners();
    });

    audioPlayer.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    });

    audioPlayer.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  void _onTrackCompleted() {
    if (loopMode == LoopMode.one) {
      audioPlayer.seek(Duration.zero);
      audioPlayer.play();
    } else if (currentQueueIndex + 1 < playQueue.length) {
      skipNext();
    } else if (loopMode == LoopMode.all && playQueue.isNotEmpty) {
      playFromQueueIndex(0);
    }
  }

  // ===========================================================================
  // PERSISTENCIA LOCAL (Biblioteca y Playlists en el teléfono)
  // ===========================================================================
  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    final libJson = prefs.getStringList('library_items') ?? [];
    final plJson = prefs.getStringList('playlists_items') ?? [];

    library = libJson
        .map((e) => MediaItemModel.fromJson(jsonDecode(e)))
        .where((item) => File(item.filePath).existsSync())
        .toList();

    playlists = plJson
        .map((e) => PlaylistModel.fromJson(jsonDecode(e)))
        .toList();

    notifyListeners();
  }

  Future<void> _savePersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'library_items',
      library.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setStringList(
      'playlists_items',
      playlists.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  // ===========================================================================
  // REPRODUCTOR ESTILO APPLE MUSIC Y COLA ("A CONTINUACIÓN")
  // ===========================================================================
  Future<void> playItem(MediaItemModel item, {List<MediaItemModel>? contextList}) async {
    if (contextList != null && contextList.isNotEmpty) {
      playQueue = List.from(contextList);
      currentQueueIndex = playQueue.indexWhere((e) => e.id == item.id);
      if (currentQueueIndex == -1) {
        playQueue.insert(0, item);
        currentQueueIndex = 0;
      }
    } else {
      playQueue = [item];
      currentQueueIndex = 0;
    }
    await _loadAndPlayCurrent();
  }

  Future<void> playFromQueueIndex(int index) async {
    if (index < 0 || index >= playQueue.length) return;
    currentQueueIndex = index;
    await _loadAndPlayCurrent();
  }

  Future<void> _loadAndPlayCurrent() async {
    final track = currentTrack;
    if (track == null) return;

    try {
      await audioPlayer.setFilePath(track.filePath);
      audioPlayer.play();
      notifyListeners();

      // Si aún no tiene letra guardada, intentar obtenerla automáticamente
      if (track.lyrics == null || track.lyrics!.trim().isEmpty) {
        fetchLyricsForTrack(track);
      }
    } catch (e) {
      debugPrint('Error al reproducir archivo: $e');
    }
  }

  void togglePlayPause() {
    if (audioPlayer.playing) {
      audioPlayer.pause();
    } else {
      audioPlayer.play();
    }
  }

  void seekTo(Duration target) {
    audioPlayer.seek(target);
  }

  void skipNext() {
    if (playQueue.isEmpty) return;
    if (shuffleEnabled && playQueue.length > 1) {
      final nextIdx = (currentQueueIndex + 1 + DateTime.now().millisecond) % playQueue.length;
      playFromQueueIndex(nextIdx);
      return;
    }
    if (currentQueueIndex + 1 < playQueue.length) {
      playFromQueueIndex(currentQueueIndex + 1);
    } else if (loopMode == LoopMode.all) {
      playFromQueueIndex(0);
    }
  }

  void skipPrevious() {
    if (position.inSeconds > 3) {
      seekTo(Duration.zero);
      return;
    }
    if (currentQueueIndex - 1 >= 0) {
      playFromQueueIndex(currentQueueIndex - 1);
    }
  }

  /// "Reproducir a continuación" (Play Next estilo Apple Music)
  void playNextInQueue(MediaItemModel item) {
    if (playQueue.isEmpty) {
      playItem(item);
      return;
    }
    final insertPos = (currentQueueIndex + 1).clamp(0, playQueue.length);
    playQueue.insert(insertPos, item);
    notifyListeners();
  }

  /// "Agregar al final de la cola"
  void addToEndOfQueue(MediaItemModel item) {
    if (playQueue.isEmpty) {
      playItem(item);
      return;
    }
    playQueue.add(item);
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= playQueue.length) return;
    playQueue.removeAt(index);
    if (index < currentQueueIndex) {
      currentQueueIndex--;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    notifyListeners();
  }

  void cycleLoopMode() {
    if (loopMode == LoopMode.off) {
      loopMode = LoopMode.all;
    } else if (loopMode == LoopMode.all) {
      loopMode = LoopMode.one;
    } else {
      loopMode = LoopMode.off;
    }
    notifyListeners();
  }

  void toggleLyricsView() {
    showLyrics = !showLyrics;
    notifyListeners();
  }

  // ===========================================================================
  // LETRAS AUTOMÁTICAS (LRCLIB API) Y EDICIÓN MANUAL
  // ===========================================================================
  Future<void> fetchLyricsForTrack(MediaItemModel track) async {
    try {
      // Limpiar sufijos comunes de YouTube como (Official Video), [Lyrics], etc.
      final cleanTitle = track.title
          .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'official video|video oficial|lyrics|audio|hd|4k', caseSensitive: false), '')
          .trim();

      final query = Uri.encodeComponent('$cleanTitle ${track.artist}');
      final uri = Uri.parse('https://lrclib.net/api/search?q=$query');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          final first = data.first;
          final synced = first['syncedLyrics'] as String?;
          final plain = first['plainLyrics'] as String?;
          final chosenLyrics = (synced != null && synced.trim().isNotEmpty) ? synced : plain;

          if (chosenLyrics != null && chosenLyrics.trim().isNotEmpty) {
            track.lyrics = chosenLyrics;
            await _savePersistedData();
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('No se pudo obtener letra automática: $e');
    }
  }

  Future<void> updateTrackLyrics(MediaItemModel track, String customLyrics) async {
    track.lyrics = customLyrics;
    await _savePersistedData();
    notifyListeners();
  }

  // ===========================================================================
  // PLAYLISTS (CREAR, AGREGAR, ELIMINAR)
  // ===========================================================================
  Future<void> createPlaylist(String name) async {
    final newPl = PlaylistModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      mediaIds: [],
    );
    playlists.add(newPl);
    await _savePersistedData();
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    playlists.removeWhere((p) => p.id == playlistId);
    await _savePersistedData();
    notifyListeners();
  }

  Future<void> addTrackToPlaylist(String playlistId, String mediaId) async {
    final pl = playlists.firstWhere((p) => p.id == playlistId);
    if (!pl.mediaIds.contains(mediaId)) {
      pl.mediaIds.add(mediaId);
      await _savePersistedData();
      notifyListeners();
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String mediaId) async {
    final pl = playlists.firstWhere((p) => p.id == playlistId);
    pl.mediaIds.remove(mediaId);
    await _savePersistedData();
    notifyListeners();
  }

  List<MediaItemModel> getPlaylistTracks(PlaylistModel pl) {
    return pl.mediaIds
        .map((id) => library.where((m) => m.id == id).firstOrNull)
        .whereType<MediaItemModel>()
        .toList();
  }

  // ===========================================================================
  // EXTRACTOR DE FORMATOS YOUTUBE (MP3, M4A, MP4 por calidad) Y DESCARGA
  // ===========================================================================
  Future<Map<String, dynamic>> analyzeYoutubeUrl(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);

      final List<DownloadFormatOption> options = [];

      // 1. Opciones de Audio (M4A y MP3 en distintas calidades)
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.first;
        final kbps = (bestAudio.bitrate.kiloBitsPerSecond).round();

        options.add(DownloadFormatOption(
          format: 'M4A',
          qualityLabel: 'Audio Original ($kbps kbps) • M4A',
          downloadUrl: bestAudio.url.toString(),
          sizeBytes: bestAudio.size.totalBytes,
        ));

        options.add(DownloadFormatOption(
          format: 'MP3',
          qualityLabel: 'Audio Alta Calidad ($kbps kbps) • MP3',
          downloadUrl: bestAudio.url.toString(),
          sizeBytes: bestAudio.size.totalBytes,
        ));

        if (audioStreams.length > 1) {
          final lowAudio = audioStreams.last;
          final lowKbps = (lowAudio.bitrate.kiloBitsPerSecond).round();
          options.add(DownloadFormatOption(
            format: 'M4A',
            qualityLabel: 'Audio Ligero ($lowKbps kbps) • M4A',
            downloadUrl: lowAudio.url.toString(),
            sizeBytes: lowAudio.size.totalBytes,
          ));
        }
      }

      // 2. Opciones de Video MP4 con Audio (1080p, 720p, 480p, 360p...)
      final muxedStreams = manifest.muxed.sortByVideoQuality();
      final seenQualities = <String>{};
      for (final stream in muxedStreams) {
        final qLabel = stream.qualityLabel; // ej. '720p', '360p'
        if (!seenQualities.contains(qLabel)) {
          seenQualities.add(qLabel);
          options.add(DownloadFormatOption(
            format: 'MP4',
            qualityLabel: 'Video $qLabel (${stream.size.totalMegaBytes.toStringAsFixed(1)} MB) • MP4',
            downloadUrl: stream.url.toString(),
            sizeBytes: stream.size.totalBytes,
          ));
        }
      }

      return {
        'video': video,
        'options': options,
      };
    } finally {
      yt.close();
    }
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.audio,
        Permission.videos,
      ].request();

      final publicMusicDir = Directory('/storage/emulated/0/Music/AppleMusicYT');
      try {
        if (!await publicMusicDir.exists()) {
          await publicMusicDir.create(recursive: true);
        }
        return publicMusicDir;
      } catch (_) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) return extDir;
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> startDownload({
    required Video video,
    required DownloadFormatOption option,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final thumbUrl = video.thumbnails.highResUrl;

    final task = ActiveDownloadTask(
      id: taskId,
      title: video.title,
      format: option.format,
      qualityLabel: option.qualityLabel,
      thumbnailUrl: thumbUrl,
      progress: 0.0,
      status: 'Descargando...',
    );

    activeDownloads.insert(0, task);
    notifyListeners();

    try {
      final dir = await _resolveDownloadDirectory();
      final safeTitle = video.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .trim();
      final ext = option.format.toLowerCase();
      final savePath = '${dir.path}/${safeTitle}_$taskId.$ext';

      await _dio.download(
        option.downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
            notifyListeners();
          }
        },
      );

      final savedFile = File(savePath);
      final actualBytes = await savedFile.length();

      final mediaItem = MediaItemModel(
        id: taskId,
        title: video.title,
        artist: video.author,
        filePath: savePath,
        format: option.format,
        qualityLabel: option.qualityLabel,
        thumbnailUrl: thumbUrl,
        durationSeconds: video.duration?.inSeconds ?? 0,
        fileSizeBytes: actualBytes,
        addedAt: DateTime.now(),
      );

      library.insert(0, mediaItem);
      task.progress = 1.0;
      task.status = 'Guardado en memoria del teléfono';
      await _savePersistedData();
      notifyListeners();

      // Buscar letra automáticamente al terminar la descarga
      fetchLyricsForTrack(mediaItem);
    } catch (e) {
      task.status = 'Error: $e';
      notifyListeners();
    }
  }

  // ===========================================================================
  // GESTOR DE ARCHIVOS (ELIMINAR Y RENOMBRAR EN LA MEMORIA DEL TELÉFONO)
  // ===========================================================================
  Future<void> deleteMediaItem(MediaItemModel item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    library.removeWhere((e) => e.id == item.id);
    playQueue.removeWhere((e) => e.id == item.id);
    for (final pl in playlists) {
      pl.mediaIds.remove(item.id);
    }
    await _savePersistedData();
    notifyListeners();
  }

  Future<void> renameMediaItem(MediaItemModel item, String newTitle, String newArtist) async {
    item.title = newTitle.trim();
    item.artist = newArtist.trim();
    await _savePersistedData();
    notifyListeners();
  }
}
