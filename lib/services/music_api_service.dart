import 'package:dio/dio.dart';

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  String? _proxyUrl;
  late Dio _dio;

  MusicApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  void setProxy(String? proxyUrl) {
    _proxyUrl = proxyUrl;
    if (proxyUrl != null && proxyUrl.isNotEmpty) {
      _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        proxy: proxyUrl,
      ));
    }
  }

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    try {
      final response = await _dio.get(
        'https://api.spotify.me/search',
        queryParameters: {
          'q': query,
          'type': 'track',
          'limit': '20',
        },
        options: Options(headers: {
          'Authorization': 'Bearer YOUR_SPOTIFY_TOKEN',
        }),
      );
      
      final tracks = response.data['tracks']?['items'] as List? ?? [];
      return tracks.map((track) => {
        'id': track['id'],
        'title': track['name'],
        'artist': (track['artists'] as List).map((a) => a['name']).join(', '),
        'album': track['album']?['name'],
        'albumArt': track['album']?['images']?.first?['url'],
        'audioUrl': track['preview_url'],
        'duration': track['duration_ms'],
      }).toList();
    } catch (e) {
      return _searchAlternative(query);
    }
  }

  Future<List<Map<String, dynamic>>> _searchAlternative(String query) async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {'q': query, 'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => {
        'id': track['id'],
        'title': track['title'],
        'artist': track['artist']?['name'] ?? 'Unknown Artist',
        'album': track['album']?['title'] ?? 'Unknown Album',
        'albumArt': track['album']?['cover_medium'] ?? track['album']?['cover'],
        'audioUrl': track['preview'],
        'duration': (track['duration'] ?? 0) * 1000,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTopCharts() async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/chart/0/tracks',
        queryParameters: {'limit': 20},
      );
      
      final tracks = response.data['data'] as List? ?? [];
      return tracks.map((track) => {
        'id': track['id'],
        'title': track['title'],
        'artist': track['artist']?['name'] ?? 'Unknown Artist',
        'album': track['album']?['title'] ?? 'Unknown Album',
        'albumArt': track['album']?['cover_medium'] ?? track['album']?['cover'],
        'audioUrl': track['preview'],
        'duration': (track['duration'] ?? 0) * 1000,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> getFullAudioUrl(String trackId) async {
    try {
      final response = await _dio.get(
        'https://api.deezer.com/track/$trackId',
      );
      
      return response.data['preview'];
    } catch (e) {
      return null;
    }
  }
}
