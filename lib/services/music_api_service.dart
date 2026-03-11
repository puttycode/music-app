import 'package:dio/dio.dart';

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  late Dio _dio;
  String? _customBaseUrl;

  MusicApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  void setCustomApiUrl(String? url) {
    _customBaseUrl = url;
  }

  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_customBaseUrl/search',
          queryParameters: {'keywords': query, 'limit': 20},
        );
        
        final songs = response.data['result']?['songs'] as List? ?? [];
        return songs.map((song) => _parseNeteaseSong(song)).toList();
      } catch (e) {
        print('Custom API error: $e');
      }
    }
    
    return _searchFallback(query);
  }

  Future<List<Map<String, dynamic>>> _searchFallback(String query) async {
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
        'isPreview': true,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _parseNeteaseSong(dynamic song) {
    return {
      'id': song['id'],
      'title': song['name'],
      'artist': (song['artists'] as List?)?.first?['name'] ?? 'Unknown Artist',
      'album': song['album']?['name'] ?? 'Unknown Album',
      'albumArt': song['album']?['picUrl'] ?? song['album']?['blurPicUrl'],
      'audioUrl': null,
      'duration': song['duration'] ?? 0,
      'isPreview': true,
    };
  }

  Future<Map<String, dynamic>?> getSongUrl(int songId) async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_customBaseUrl/song/url',
          queryParameters: {'id': songId},
        );
        
        final data = response.data['data'] as List?;
        if (data != null && data.isNotEmpty) {
          return {
            'url': data.first['url'],
            'isPreview': data.first['url'] == null,
          };
        }
      } catch (e) {
        print('Get song URL error: $e');
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getTopCharts() async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_customBaseUrl/top/song',
          queryParameters: {'type': 0, 'limit': 20},
        );
        
        final songs = response.data['data'] as List? ?? [];
        return songs.map((song) => _parseNeteaseSong(song)).toList();
      } catch (e) {
        print('Get top charts error: $e');
      }
    }
    
    return _getFallbackCharts();
  }

  Future<List<Map<String, dynamic>>> _getFallbackCharts() async {
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
        'isPreview': true,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> getLyrics(int songId) async {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      try {
        final response = await _dio.get(
          '$_customBaseUrl/lyric',
          queryParameters: {'id': songId},
        );
        
        return response.data['lrc']?['lyric'];
      } catch (e) {
        print('Get lyrics error: $e');
      }
    }
    return null;
  }
}
