import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';

enum MusicSource {
  audius,
  deezer,
}

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  late Dio _dio;
  String? _apiKey;
  MusicSource _currentSource = MusicSource.audius;

  static const String _audiusApi = 'https://api.audius.co/v1';

  MusicApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  void setApiKey(String? key) {
    _apiKey = key;
  }

  void setSource(MusicSource source) {
    _currentSource = source;
  }

  MusicSource get currentSource => _currentSource;

  Future<List<Song>> searchSongs(String query) async {
    switch (_currentSource) {
      case MusicSource.audius:
        return _searchAudius(query);
      case MusicSource.deezer:
        return _searchDeezer(query);
    }
  }

  Future<List<Song>> _searchAudius(String query) async {
    try {
      final response = await _dio.get(
        '$_audiusApi/tracks/search',
        queryParameters: {'query': query, 'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => Song(
        id: track['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: track['title'] ?? 'Unknown',
        artist: track['user']?['name'] ?? 'Unknown Artist',
        album: 'Audius',
        albumArt: track['artwork']?['480x480'] ?? track['artwork']?['150x150'],
        audioUrl: track['audio']?['320'] ?? track['audio'],
        duration: Duration(milliseconds: track['duration'] ?? 0),
        isLocal: false,
      )).toList();
    } catch (e) {
      print('Audius API error: $e');
      return [];
    }
  }

  Future<List<Song>> _searchDeezer(String query) async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => Song(
        id: track['id'] ?? 0,
        title: track['title'] ?? 'Unknown',
        artist: track['artist']?['name'] ?? 'Unknown Artist',
        album: track['album']?['title'] ?? 'Unknown Album',
        albumArt: track['album']?['cover_medium'] ?? track['album']?['cover'],
        audioUrl: track['preview'],
        duration: Duration(milliseconds: (track['duration'] ?? 0) * 1000),
        isLocal: false,
      )).toList();
    } catch (e) {
      print('Deezer API error: $e');
      return [];
    }
  }

  Future<List<Song>> getTopCharts() async {
    switch (_currentSource) {
      case MusicSource.audius:
        return _getAudiusTrending();
      case MusicSource.deezer:
        return _getDeezerCharts();
    }
  }

  Future<List<Song>> _getAudiusTrending() async {
    try {
      final response = await _dio.get(
        '$_audiusApi/tracks/trending',
        queryParameters: {'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => Song(
        id: track['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
        title: track['title'] ?? 'Unknown',
        artist: track['user']?['name'] ?? 'Unknown Artist',
        album: 'Audius Trending',
        albumArt: track['artwork']?['480x480'] ?? track['artwork']?['150x150'],
        audioUrl: track['audio']?['320'] ?? track['audio'],
        duration: Duration(milliseconds: track['duration'] ?? 0),
        isLocal: false,
      )).toList();
    } catch (e) {
      return _getDeezerCharts();
    }
  }

  Future<List<Song>> _getDeezerCharts() async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/chart/0/tracks',
        queryParameters: {'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => Song(
        id: track['id'] ?? 0,
        title: track['title'] ?? 'Unknown',
        artist: track['artist']?['name'] ?? 'Unknown Artist',
        album: track['album']?['title'] ?? 'Unknown Album',
        albumArt: track['album']?['cover_medium'] ?? track['album']?['cover'],
        audioUrl: track['preview'],
        duration: Duration(milliseconds: (track['duration'] ?? 0) * 1000),
        isLocal: false,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return _currentSource == MusicSource.audius;
  }
}
