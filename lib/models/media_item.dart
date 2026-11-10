import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class MediaItemModel {
  final String id;
  String title;
  String artist;
  final String filePath;
  final String format; // 'MP3', 'M4A', 'MP4'
  final String qualityLabel; // ej. '128 kbps', '1080p', '720p'
  final String thumbnailUrl;
  final int durationSeconds;
  final int fileSizeBytes;
  final DateTime addedAt;
  String? lyrics; // Letra plana o en formato [mm:ss.xx] LRC

  MediaItemModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.filePath,
    required this.format,
    required this.qualityLabel,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.addedAt,
    this.lyrics,
  });

  bool get isVideo => format.toUpperCase() == 'MP4';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'filePath': filePath,
        'format': format,
        'qualityLabel': qualityLabel,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'fileSizeBytes': fileSizeBytes,
        'addedAt': addedAt.toIso8601String(),
        'lyrics': lyrics,
      };

  factory MediaItemModel.fromJson(Map<String, dynamic> json) => MediaItemModel(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Sin título',
        artist: json['artist'] ?? 'Artista desconocido',
        filePath: json['filePath'] ?? '',
        format: json['format'] ?? 'M4A',
        qualityLabel: json['qualityLabel'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        durationSeconds: json['durationSeconds'] ?? 0,
        fileSizeBytes: json['fileSizeBytes'] ?? 0,
        addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
        lyrics: json['lyrics'],
      );

  /// Parsea letras con marcas de tiempo [mm:ss.xx] si existen
  List<LyricLine> parseSynchronizedLyrics() {
    if (lyrics == null || lyrics!.trim().isEmpty) return [];
    final regExp = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)');
    final lines = <LyricLine>[];

    for (final rawLine in lyrics!.split('\n')) {
      final match = regExp.firstMatch(rawLine);
      if (match != null) {
        final mins = int.tryParse(match.group(1)!) ?? 0;
        final secsDouble = double.tryParse(match.group(2)!) ?? 0.0;
        final ms = (mins * 60 * 1000) + (secsDouble * 1000).round();
        final text = match.group(3)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            timestamp: Duration(milliseconds: ms),
            text: text,
          ));
        }
      } else if (rawLine.trim().isNotEmpty) {
        lines.add(LyricLine(
          timestamp: Duration.zero,
          text: rawLine.trim(),
        ));
      }
    }
    return lines;
  }
}

class PlaylistModel {
  final String id;
  String name;
  final List<String> mediaIds;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.mediaIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mediaIds': mediaIds,
      };

  factory PlaylistModel.fromJson(Map<String, dynamic> json) => PlaylistModel(
        id: json['id'] ?? '',
        name: json['name'] ?? 'Playlist',
        mediaIds: List<String>.from(json['mediaIds'] ?? []),
      );
}

class DownloadFormatOption {
  final String format; // 'MP3', 'M4A', 'MP4'
  final String qualityLabel; // ej. 'Audio Original (128 kbps) • M4A'
  final StreamInfo streamInfo;
  final int sizeBytes;

  DownloadFormatOption({
    required this.format,
    required this.qualityLabel,
    required this.streamInfo,
    required this.sizeBytes,
  });
}

class ActiveDownloadTask {
  final String id;
  final String title;
  final String format;
  final String qualityLabel;
  final String thumbnailUrl;
  double progress; // 0.0 a 1.0
  String status; // 'Descargando...', 'Completado', 'Error'

  ActiveDownloadTask({
    required this.id,
    required this.title,
    required this.format,
    required this.qualityLabel,
    required this.thumbnailUrl,
    this.progress = 0.0,
    this.status = 'Iniciando...',
  });
}
