import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('AudioSession init warning: $e');
    }

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
    try {
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
    } catch (e) {
      debugPrint('Error cargando datos locales: $e');
    }
  }

  Future<void> _savePersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'library_items',
        library.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setStringList(
        'playlists_items',
        playlists.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (e) {
      debugPrint('Error guardando datos locales: $e');
    }
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

  void playNextInQueue(MediaItemModel item) {
    if (playQueue.isEmpty) {
      playItem(item);
      return;
    }
    final insertPos = (currentQueueIndex + 1).clamp(0, playQueue.length);
    playQueue.insert(insertPos, item);
    notifyListeners();
  }

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
      final cleanTitle = track.title
          .replaceAll(RegExp(r'\(.*?\)|\[.*?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'official video|video oficial|lyrics|letra completa|letra|audio|hd|4k', caseSensitive: false), '')
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
  // MOTOR DE EXTRACCIÓN DIRECTA YOUTUBE (ANTI-403 + CHUNKED DOWNLOAD)
  // ===========================================================================
  String? extractVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'shorts/([a-zA-Z0-9_-]{11})'),
      RegExp(r'embed/([a-zA-Z0-9_-]{11})'),
    ];
    for (final reg in patterns) {
      final match = reg.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  static const List<Map<String, dynamic>> _innertubeClients = [
    {
      'name': 'ANDROID_VR',
      'id': '28',
      'version': '1.60.19',
      'userAgent':
          'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      'osName': 'Android',
      'osVersion': '12L',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
      'androidSdkVersion': 32,
    },
    {
      'name': 'IOS',
      'id': '5',
      'version': '19.45.4',
      'userAgent':
          'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
      'osName': 'iPhone',
      'osVersion': '18.1.0.22B83',
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
    },
    {
      'name': 'ANDROID_CREATOR',
      'id': '14',
      'version': '24.30.100',
      'userAgent':
          'com.google.android.apps.youtube.creator/24.30.100 (Linux; U; Android 14) gzip',
      'osName': 'Android',
      'osVersion': '14',
      'androidSdkVersion': 34,
    },
  ];

  Future<Map<String, dynamic>?> _queryInnertubeClient(
    String videoId,
    Map<String, dynamic> client,
  ) async {
    final contextMap = <String, dynamic>{
      'clientName': client['name'],
      'clientVersion': client['version'],
      'hl': 'es',
      'gl': 'US',
      'osName': client['osName'],
      'osVersion': client['osVersion'],
    };
    if (client['deviceMake'] != null) contextMap['deviceMake'] = client['deviceMake'];
    if (client['deviceModel'] != null) contextMap['deviceModel'] = client['deviceModel'];
    if (client['androidSdkVersion'] != null) {
      contextMap['androidSdkVersion'] = client['androidSdkVersion'];
    }

    final resp = await http
        .post(
          Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': client['userAgent'] as String,
            'X-Goog-Api-Format-Version': '2',
            'X-YouTube-Client-Name': client['id'] as String,
            'X-YouTube-Client-Version': client['version'] as String,
            'Origin': 'https://www.youtube.com',
          },
          body: jsonEncode({
            'videoId': videoId,
            'context': {'client': contextMap},
            'contentCheckOk': true,
            'racyCheckOk': true,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final streamingData = decoded['streamingData'] as Map<String, dynamic>?;
      if (streamingData != null) {
        final formats = (streamingData['formats'] as List?) ?? [];
        final adaptive = (streamingData['adaptiveFormats'] as List?) ?? [];
        if ([...formats, ...adaptive].any((f) => f['url'] != null)) {
          return decoded;
        }
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> analyzeYoutubeUrl(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      throw Exception('No se detectó un ID de video válido en la URL actual.');
    }

    Map<String, dynamic>? playerResponse;
    String activeUserAgent = _innertubeClients.first['userAgent'] as String;

    for (final client in _innertubeClients) {
      try {
        final res = await _queryInnertubeClient(videoId, client);
        if (res != null) {
          playerResponse = res;
          activeUserAgent = client['userAgent'] as String;
          break;
        }
      } catch (e) {
        debugPrint('Intento cliente ${client['name']} falló: $e');
      }
    }

    if (playerResponse == null) {
      throw Exception('No se pudieron obtener enlaces directos para este video.');
    }

    final videoDetails = (playerResponse['videoDetails'] as Map<String, dynamic>?) ?? {};
    final title = (videoDetails['title'] as String?) ?? 'Canción de YouTube';
    final author = (videoDetails['author'] as String?) ?? 'Artista';
    final durationSec = int.tryParse('${videoDetails['lengthSeconds'] ?? '0'}') ?? 0;
    final thumbUrl = 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

    final videoMeta = VideoMetadataModel(
      id: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbUrl,
      durationSeconds: durationSec,
    );

    final streamingData = playerResponse['streamingData'] as Map<String, dynamic>;
    final muxedList = List<Map<String, dynamic>>.from(streamingData['formats'] ?? []);
    final adaptiveList = List<Map<String, dynamic>>.from(streamingData['adaptiveFormats'] ?? []);

    final List<DownloadFormatOption> options = [];

    // 1. Extraer flujos de solo Audio (M4A y MP3)
    final audioStreams = adaptiveList.where((f) {
      final mime = (f['mimeType'] as String? ?? '').toLowerCase();
      return mime.startsWith('audio/') && f['url'] != null;
    }).toList();

    // Preferir audio/mp4 (m4a nativo) primero
    audioStreams.sort((a, b) {
      final aMp4 = (a['mimeType'] as String? ?? '').contains('mp4') ? 1 : 0;
      final bMp4 = (b['mimeType'] as String? ?? '').contains('mp4') ? 1 : 0;
      if (aMp4 != bMp4) return bMp4.compareTo(aMp4);
      return ((b['bitrate'] ?? 0) as int).compareTo((a['bitrate'] ?? 0) as int);
    });

    if (audioStreams.isNotEmpty) {
      final bestAudio = audioStreams.first;
      final bitrateKbps = (((bestAudio['bitrate'] ?? 128000) as int) / 1000).round();
      final contentLen = int.tryParse('${bestAudio['contentLength'] ?? '0'}') ?? 0;

      options.add(DownloadFormatOption(
        format: 'M4A',
        qualityLabel: 'Audio Original ($bitrateKbps kbps) • M4A',
        downloadUrl: bestAudio['url'] as String,
        sizeBytes: contentLen,
        userAgent: activeUserAgent,
      ));

      options.add(DownloadFormatOption(
        format: 'MP3',
        qualityLabel: 'Audio Alta Calidad ($bitrateKbps kbps) • MP3',
        downloadUrl: bestAudio['url'] as String,
        sizeBytes: contentLen,
        userAgent: activeUserAgent,
      ));

      if (audioStreams.length > 1) {
        final lightAudio = audioStreams.last;
        final lowKbps = (((lightAudio['bitrate'] ?? 64000) as int) / 1000).round();
        final lowLen = int.tryParse('${lightAudio['contentLength'] ?? '0'}') ?? 0;
        options.add(DownloadFormatOption(
          format: 'M4A',
          qualityLabel: 'Audio Ligero ($lowKbps kbps) • M4A',
          downloadUrl: lightAudio['url'] as String,
          sizeBytes: lowLen,
          userAgent: activeUserAgent,
        ));
      }
    }

    // 2. Extraer flujos de Video MP4
    final allVideoStreams = [
      ...muxedList.where((f) => f['url'] != null),
      ...adaptiveList.where((f) {
        final mime = (f['mimeType'] as String? ?? '').toLowerCase();
        return mime.startsWith('video/mp4') && f['url'] != null;
      }),
    ];

    final seenQualities = <String>{};
    for (final vStream in allVideoStreams) {
      final qLabel = (vStream['qualityLabel'] as String?) ?? (vStream['quality'] as String?) ?? '360p';
      if (!seenQualities.contains(qLabel)) {
        seenQualities.add(qLabel);
        final contentLen = int.tryParse('${vStream['contentLength'] ?? '0'}') ?? 0;
        final mbText = contentLen > 0
            ? ' (${(contentLen / (1024 * 1024)).toStringAsFixed(1)} MB)'
            : '';

        options.add(DownloadFormatOption(
          format: 'MP4',
          qualityLabel: 'Video $qLabel$mbText • MP4',
          downloadUrl: vStream['url'] as String,
          sizeBytes: contentLen,
          userAgent: activeUserAgent,
        ));
      }
    }

    if (options.isEmpty) {
      throw Exception('No se encontraron formatos disponibles.');
    }

    return {
      'video': videoMeta,
      'options': options,
    };
  }

  /// Descarga por bloques (Range chunks) para evitar el bloqueo 403 de googlevideo.com
  Future<void> _downloadStreamBypass403({
    required String url,
    required String savePath,
    required String userAgent,
    required int totalBytes,
    required void Function(double progress) onProgress,
  }) async {
    final outFile = File(savePath);
    if (await outFile.exists()) {
      await outFile.delete();
    }

    // Si conocemos el tamaño total, descargamos en bloques de 4 MB con parámetro &range=start-end
    // Tal como lo hace la app nativa de YouTube para evitar errores 403.
    if (totalBytes > 0) {
      const int chunkSize = 4 * 1024 * 1024; // 4 MB por bloque
      final sink = outFile.openWrite(mode: FileMode.writeOnlyAppend);
      int downloaded = 0;

      try {
        while (downloaded < totalBytes) {
          final int end = (downloaded + chunkSize - 1 < totalBytes)
              ? downloaded + chunkSize - 1
              : totalBytes - 1;

          final separator = url.contains('?') ? '&' : '?';
          final rangedUrl = '$url${separator}range=$downloaded-$end';

          final resp = await _dio.get<List<int>>(
            rangedUrl,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'User-Agent': userAgent,
                'Range': 'bytes=$downloaded-$end',
                'Origin': 'https://www.youtube.com',
                'Referer': 'https://www.youtube.com/',
              },
            ),
          );

          final bytes = resp.data;
          if (bytes == null || bytes.isEmpty) break;

          sink.add(bytes);
          downloaded += bytes.length;
          onProgress((downloaded / totalBytes).clamp(0.0, 1.0));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      return;
    }

    // Si no viene contentLength, descarga directa con cabeceras completas de cliente móvil
    await _dio.download(
      url,
      savePath,
      options: Options(
        headers: {
          'User-Agent': userAgent,
          'Origin': 'https://www.youtube.com',
          'Referer': 'https://www.youtube.com/',
        },
      ),
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress((received / total).clamp(0.0, 1.0));
        }
      },
    );
  }

  Future<Directory> _resolveDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final musicDir = Directory('${extDir.path}/Music');
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          return musicDir;
        }
      } catch (e) {
        debugPrint('Fallback a DocumentDirectory: $e');
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> startDownload({
    required VideoMetadataModel video,
    required DownloadFormatOption option,
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    final task = ActiveDownloadTask(
      id: taskId,
      title: video.title,
      format: option.format,
      qualityLabel: option.qualityLabel,
      thumbnailUrl: video.thumbnailUrl,
      progress: 0.0,
      status: 'Descargando...',
    );

    activeDownloads.insert(0, task);
    notifyListeners();

    try {
      final dir = await _resolveDownloadDirectory();
      final safeTitle = video.title
          .replaceAll(RegExp(r'[^\w\s-]', unicode: true), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final finalName = safeTitle.isEmpty ? 'track_$taskId' : safeTitle;
      final ext = option.format.toLowerCase();
      final savePath = '${dir.path}/${finalName}_$taskId.$ext';

      await _downloadStreamBypass403(
        url: option.downloadUrl,
        savePath: savePath,
        userAgent: option.userAgent,
        totalBytes: option.sizeBytes,
        onProgress: (p) {
          task.progress = p;
          notifyListeners();
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
        thumbnailUrl: video.thumbnailUrl,
        durationSeconds: video.durationSeconds,
        fileSizeBytes: actualBytes,
        addedAt: DateTime.now(),
      );

      library.insert(0, mediaItem);
      task.progress = 1.0;
      task.status = 'Completado • Guardado en memoria';
      await _savePersistedData();
      notifyListeners();

      // Buscar letra automáticamente al terminar la descarga
      fetchLyricsForTrack(mediaItem);
    } catch (e) {
      task.status = 'Error al descargar: $e';
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
