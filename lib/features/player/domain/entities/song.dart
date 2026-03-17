import 'package:equatable/equatable.dart';

class Song extends Equatable {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String? albumArt;
  final String? audioUrl;
  final Duration duration;
  final bool isLocal;
  final String? localPath;
  final List<String>? lyrics;
  final DateTime? playedAt;
  final String? releaseDate;
  final String? format;
  final String? bitrate;
  final String? sampleRate;
  final int? fileSize;
  final String? publisher;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArt,
    this.audioUrl,
    required this.duration,
    this.isLocal = false,
    this.localPath,
    this.lyrics,
    this.playedAt,
    this.releaseDate,
    this.format,
    this.bitrate,
    this.sampleRate,
    this.fileSize,
    this.publisher,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final durationValue = json['duration'];
    Duration duration;
    
    if (durationValue is int) {
      if (durationValue > 10000) {
        duration = Duration(milliseconds: durationValue);
      } else {
        duration = Duration(seconds: durationValue);
      }
    } else {
      duration = const Duration(seconds: 0);
    }
    
    return Song(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      artist: json['artist']?['name'] ?? json['artist_name'] ?? 'Unknown Artist',
      album: json['album']?['title'] ?? json['album_title'] ?? 'Unknown Album',
      albumArt: json['album']?['cover_medium'] ?? 
                json['album']?['cover'] ?? 
                json['cover_medium'] ??
                json['cover'],
      audioUrl: json['preview'] ?? json['audio_url'],
      duration: duration,
      isLocal: false,
    );
  }

  factory Song.fromLocal(Map<String, dynamic> json) {
    final durationValue = json['duration'];
    Duration duration;
    
    if (durationValue is int) {
      if (durationValue > 10000) {
        duration = Duration(milliseconds: durationValue);
      } else {
        duration = Duration(seconds: durationValue);
      }
    } else {
      duration = const Duration(seconds: 0);
    }
    
    return Song(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      albumArt: json['albumArt'],
      audioUrl: json['audioUrl'],
      duration: duration,
      isLocal: true,
      localPath: json['localPath'],
      lyrics: json['lyrics'] != null ? List<String>.from(json['lyrics']) : null,
      playedAt: json['playedAt'] != null ? DateTime.parse(json['playedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'duration': duration.inMilliseconds,
      'isLocal': isLocal,
      'localPath': localPath,
      'lyrics': lyrics,
      'playedAt': playedAt?.toIso8601String(),
    };
  }

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    String? albumArt,
    String? audioUrl,
    Duration? duration,
    bool? isLocal,
    String? localPath,
    List<String>? lyrics,
    DateTime? playedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArt: albumArt ?? this.albumArt,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      isLocal: isLocal ?? this.isLocal,
      localPath: localPath ?? this.localPath,
      lyrics: lyrics ?? this.lyrics,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, artist, album, audioUrl, duration, isLocal, localPath, playedAt];
}
