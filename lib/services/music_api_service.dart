import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';

enum MusicSource {
  musicdl,  // 使用 musicdl API (Railway 后端)
  audius,
}

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  late Dio _dio;
  String? _apiKey;
  String? _bearerToken;
  MusicSource _currentSource = MusicSource.musicdl;

  // Audius API
  static const String _audiusApi = 'https://api.audius.co/v1';
  
  // MusicDL API (Railway 后端)
  static const String _musicdlApi = 'https://web-production-f448b.up.railway.app';

  MusicApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120), // 增加超时时间，musicdl 搜索较慢
    ));
  }

  void setCredentials({String? apiKey, String? bearerToken}) {
    _apiKey = apiKey;
    _bearerToken = bearerToken;
  }

  void setSource(MusicSource source) {
    _currentSource = source;
  }

  MusicSource get currentSource => _currentSource;

  Map<String, String> get _audiusHeaders {
    final headers = <String, String>{};
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      headers['x-api-key'] = _apiKey!;
    }
    if (_bearerToken != null && _bearerToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_bearerToken';
    }
    return headers;
  }

  Future<List<Song>> searchSongs(String query) async {
    switch (_currentSource) {
      case MusicSource.musicdl:
        return _searchMusicdl(query);
      case MusicSource.audius:
        return _searchAudius(query);
    }
  }

  // MusicDL 搜索
  Future<List<Song>> _searchMusicdl(String query) async {
    try {
      final response = await _dio.get(
        '$_musicdlApi/search',
        queryParameters: {'keyword': query, 'limit': 20},
      );
      
      if (response.data['success'] != true) {
        print('MusicDL API error: ${response.data['error']}');
        return [];
      }
      
      final results = response.data['results'] as List? ?? [];
      return results.map((track) {
        final downloadUrl = track['download_url'];
        return Song(
          id: downloadUrl?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: track['title'] ?? 'Unknown',
          artist: (track['artists'] as List?)?.join(', ') ?? 'Unknown Artist',
          album: track['album'] ?? 'MusicDL',
          albumArt: track['thumbnail'],
          audioUrl: downloadUrl,
          duration: _parseDuration(track['duration']),
          isLocal: false,
        );
      }).toList();
    } catch (e) {
      print('MusicDL API error: $e');
      return [];
    }
  }

  Duration _parseDuration(dynamic duration) {
    if (duration == null) return Duration.zero;
    if (duration is int) return Duration(seconds: duration);
    if (duration is String) {
      // 格式: "00:03:30"
      final parts = duration.split(':');
      if (parts.length == 3) {
        return Duration(
          hours: int.tryParse(parts[0]) ?? 0,
          minutes: int.tryParse(parts[1]) ?? 0,
          seconds: int.tryParse(parts[2]) ?? 0,
        );
      }
    }
    return Duration.zero;
  }

  Future<List<Song>> _searchAudius(String query) async {
    try {
      final response = await _dio.get(
        '$_audiusApi/tracks/search',
        queryParameters: {'query': query, 'limit': 20},
        options: Options(headers: _audiusHeaders),
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) {
        final streamUrl = track['stream']?['url'];
        return Song(
          id: track['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: track['title'] ?? 'Unknown',
          artist: track['user']?['name'] ?? 'Unknown Artist',
          album: 'Audius',
          albumArt: track['artwork']?['480x480'] ?? track['artwork']?['150x150'],
          audioUrl: streamUrl,
          duration: Duration(milliseconds: (track['duration'] ?? 0) * 1000),
          isLocal: false,
        );
      }).toList();
    } catch (e) {
      print('Audius API error: $e');
      return [];
    }
  }

  Future<List<Song>> getTopCharts() async {
    switch (_currentSource) {
      case MusicSource.musicdl:
        return _getMusicdlCharts();
      case MusicSource.audius:
        return _getAudiusTrending();
    }
  }

  Future<List<Song>> _getMusicdlCharts() async {
    // MusicDL 不支持 trending，使用搜索替代
    return _searchMusicdl('热门歌曲');
  }

  Future<List<Song>> _getAudiusTrending() async {
    try {
      final response = await _dio.get(
        '$_audiusApi/tracks/trending',
        queryParameters: {'limit': 20},
        options: Options(headers: _audiusHeaders),
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) {
        final streamUrl = track['stream']?['url'];
        return Song(
          id: track['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
          title: track['title'] ?? 'Unknown',
          artist: track['user']?['name'] ?? 'Unknown Artist',
          album: 'Audius Trending',
          albumArt: track['artwork']?['480x480'] ?? track['artwork']?['150x150'],
          audioUrl: streamUrl,
          duration: Duration(milliseconds: (track['duration'] ?? 0) * 1000),
          isLocal: false,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return song.audioUrl!.isNotEmpty;
  }
}
