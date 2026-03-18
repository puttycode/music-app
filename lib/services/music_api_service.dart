import 'dart:async';
import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';
import '../features/player/domain/entities/artist.dart';
import '../features/player/domain/entities/album.dart';
import '../core/utils/app_logger.dart';

enum MusicSource { custom }

class ApiError {
  final String message;
  final String operation;
  final dynamic error;

  const ApiError({
    required this.message,
    required this.operation,
    this.error,
  });
}

abstract class MusicApi {
  String get name;
  String get baseUrl;
  Future<List<Song>> searchSongs(String query);
  Future<List<Artist>> searchArtists(String query);
  Future<List<Album>> searchAlbums(String query);
  Future<List<Song>> getTopCharts();
  Future<Song?> getSongDetail(String id);
  Future<Artist?> getArtistDetail(String id);
  Future<Album?> getAlbumDetail(String id);
  Future<List<Album>> getArtistAlbums(String artistId);
  Future<List<Song>> getAlbumTracks(String albumId);
  Future<List<Song>> getChartSongs(String chartName);
  Future<List<Song>> getHotSongs();
  Future<List<Artist>> getHotArtists();
  Future<List<Album>> getNewAlbums();
  Future<String?> getSongUrl(String id, {String quality = 'exhigh'});
  Future<String?> getSongLyric(String id);
  bool isFullAudio(Song song);
}

class CustomApi implements MusicApi {
  final Dio _dio;
  static const String _defaultApiKey = 'your-secret-api-key';
  static const String _defaultDomain = 'https://music-api.codeseek.me:37280';
  
  CustomApi({String? baseUrl, String? apiKey}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? _defaultDomain,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    validateStatus: (status) => status! < 500,
    headers: {'Authorization': 'Bearer ${apiKey ?? _defaultApiKey}', 'Content-Type': 'application/json'},
  ));

  @override String get name => '自定义 API';
  @override String get baseUrl => _dio.options.baseUrl!;

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final response = await _dio.get('/api/v1/search', queryParameters: {'q': query, 'type': 'song'});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    try {
      AppLogger.log('Searching artists for: $query');
      final response = await _dio.get('/api/v1/search', queryParameters: {'q': query, 'type': 'artist'});
      AppLogger.log('Search artists response: code=${response.statusCode}, data=${response.data}');
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('Found ${results.length} artists for query: $query');
        
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      AppLogger.log('Search artists failed: code=${response.data['code']}');
      return [];
    } catch (e) { 
      AppLogger.log('Search artists error: $e');
      return []; 
    }
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    try {
      AppLogger.log('Searching albums for: $query');
      final response = await _dio.get('/api/v1/search', queryParameters: {'q': query, 'type': 'album'});
      AppLogger.log('Search albums response: code=${response.statusCode}, data=${response.data}');
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('Found ${results.length} albums for query: $query');
        
        return results.map((album) => Album(
          id: album['id']?.toString() ?? '',
          name: album['name']?.toString() ?? 'Unknown',
          artist: album['artist']?.toString(),
          cover: album['cover'] ?? album['pic'],
        )).toList();
      }
      AppLogger.log('Search albums failed: code=${response.data['code']}');
      return [];
    } catch (e) { 
      AppLogger.log('Search albums error: $e');
      return []; 
    }
  }

  @override
  Future<Song?> getSongDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/song/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return _parseSong(response.data['data']);
      }
      return null;
    } catch (e) { return null; }
  }

  @override
  Future<Artist?> getArtistDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/artist/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        return Artist(
          id: data['artist']?['id']?.toString() ?? id,
          name: data['artist']?['name']?.toString() ?? 'Unknown',
          avatar: data['artist']?['avatar'] ?? data['artist']?['pic'],
          musicNum: data['artist']?['musicNum'],
        );
      }
      return null;
    } catch (e) { return null; }
  }
  
  Future<(Artist?, List<Song>)> getArtistDetailWithSongs(String id) async {
    try {
      final response = await _dio.get('/api/v1/artist/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final artist = Artist(
          id: data['artist']?['id']?.toString() ?? id,
          name: data['artist']?['name']?.toString() ?? 'Unknown',
          avatar: data['artist']?['avatar'] ?? data['artist']?['pic'],
          musicNum: data['artist']?['musicNum'],
        );
        final songsList = data['songs'] as List? ?? [];
        final songs = songsList.map((track) => _parseSong(track)).toList();
        return (artist, songs);
      }
      return (null, <Song>[]);
    } catch (e) { return (null, <Song>[]); }
  }

  @override
  Future<Album?> getAlbumDetail(String id) async {
    try {
      final response = await _dio.get('/api/v1/album/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        return Album(
          id: data['album']?['id']?.toString() ?? id,
          name: data['album']?['name']?.toString() ?? 'Unknown',
          artist: data['album']?['artist']?.toString(),
          cover: data['album']?['pic'] ?? data['album']?['cover'],
        );
      }
      return null;
    } catch (e) { return null; }
  }
  
  Future<(Album?, List<Song>)> getAlbumDetailWithTracks(String id) async {
    try {
      final response = await _dio.get('/api/v1/album/$id');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final album = Album(
          id: data['album']?['id']?.toString() ?? id,
          name: data['album']?['name']?.toString() ?? 'Unknown',
          artist: data['album']?['artist']?.toString(),
          cover: data['album']?['pic'] ?? data['album']?['cover'],
        );
        final songsList = data['songs'] as List? ?? [];
        final songs = songsList.map((track) => _parseSong(track)).toList();
        return (album, songs);
      }
      return (null, <Song>[]);
    } catch (e) { return (null, <Song>[]); }
  }

  @override
  Future<List<Album>> getArtistAlbums(String artistId) async {
    try {
      final response = await _dio.get('/api/v1/artist/$artistId/albums');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((album) => Album(
          id: album['id']?.toString() ?? '',
          name: album['name']?.toString() ?? 'Unknown',
          artist: album['artist']?.toString(),
          cover: album['cover'] ?? album['pic'],
        )).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Song>> getAlbumTracks(String albumId) async {
    try {
      final response = await _dio.get('/api/v1/album/$albumId/tracks');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Song>> getChartSongs(String chartName) async {
    try {
      final response = await _dio.get('/api/v1/chart/$chartName/songs');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override Future<List<Song>> getTopCharts() => getChartSongs('热歌榜');

  @override
  Future<List<Song>> getHotSongs() async {
    try {
      final response = await _dio.get('/api/v1/hot/songs');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Artist>> getHotArtists() async {
    try {
      AppLogger.log('Fetching hot artists from /api/v1/hot/artists');
      final response = await _dio.get('/api/v1/hot/artists');
      AppLogger.log('Hot artists response status: ${response.statusCode}');
      AppLogger.log('Hot artists response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('Hot artists results count: ${results.length}');
        
        if (results.isNotEmpty) {
          AppLogger.log('First artist data: ${results.first}');
        }
        
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      AppLogger.log('Hot artists API returned non-200 code: ${response.data['code']}');
      return [];
    } catch (e) { 
      AppLogger.log('Hot artists fetch error: $e');
      return []; 
    }
  }

  @override
  Future<List<Album>> getNewAlbums() async {
    try {
      AppLogger.log('Fetching new albums from /api/v1/new/albums');
      final response = await _dio.get('/api/v1/new/albums');
      AppLogger.log('New albums response status: ${response.statusCode}');
      AppLogger.log('New albums response data: ${response.data}');
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('New albums results count: ${results.length}');
        
        if (results.isNotEmpty) {
          AppLogger.log('First album data: ${results.first}');
        }
        
        return results.map((album) => Album(
          id: album['id']?.toString() ?? '',
          name: album['name']?.toString() ?? 'Unknown',
          artist: album['artist']?.toString(),
          cover: album['cover'] ?? album['pic'],
        )).toList();
      }
      AppLogger.log('New albums API returned non-200 code: ${response.data['code']}');
      return [];
    } catch (e) { 
      AppLogger.log('New albums fetch error: $e');
      return []; 
    }
  }

  @override
  Future<String?> getSongUrl(String id, {String quality = 'exhigh'}) async {
    try {
      final response = await _dio.get('/api/v1/song/$id/url', queryParameters: {'quality': quality});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data']?['url'];
      }
      return null;
    } catch (e) { return null; }
  }

  @override
  Future<String?> getSongLyric(String id) async {
    try {
      final response = await _dio.get('/api/v1/song/$id/lyric');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return response.data['data']?['lyric'];
      }
      return null;
    } catch (e) { return null; }
  }

  @override bool isFullAudio(Song song) => song.duration.inSeconds > 60;

  Song _parseSong(Map<String, dynamic> track) {
    final durationValue = track['duration'];
    Duration duration;
    
    if (durationValue is int) {
      // If > 10000, assume milliseconds; otherwise assume seconds
      if (durationValue > 10000) {
        duration = Duration(milliseconds: durationValue);
      } else if (durationValue > 0) {
        duration = Duration(seconds: durationValue);
      } else {
        duration = Duration.zero;
      }
    } else {
      duration = Duration.zero;
    }
    
    return Song(
      id: int.tryParse((track['rid'] ?? track['id']).toString()) ?? DateTime.now().millisecondsSinceEpoch,
      title: track['name']?.toString() ?? track['title']?.toString() ?? 'Unknown',
      artist: track['artist']?.toString() ?? 'Unknown Artist',
      album: track['album']?.toString() ?? 'Unknown Album',
      albumArt: track['pic'] ?? track['albumArt'] ?? track['cover'],
      audioUrl: track['url'] ?? track['audioUrl'],
      duration: duration,
      isLocal: false,
    );
  }
}

class MusicApiService {
  static MusicApiService? _instance;
  static MusicApiService get instance => _instance ??= MusicApiService._();
  
  final _errorController = StreamController<ApiError>.broadcast();
  Stream<ApiError> get errorStream => _errorController.stream;
  
  MusicApi _currentApi = CustomApi();
  MusicApiService._();

  void setSource(MusicSource source, {String? customUrl, String? apiKey}) {
    _currentApi = CustomApi(baseUrl: customUrl, apiKey: apiKey);
  }

  void _emitError(String operation, String message, [dynamic error]) {
    _errorController.add(ApiError(
      message: message,
      operation: operation,
      error: error,
    ));
    AppLogger.log('API Error [$operation]: $message');
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      return await _currentApi.searchSongs(query);
    } catch (e) {
      _emitError('searchSongs', '搜索歌曲失败', e);
      return [];
    }
  }

  Future<List<Artist>> searchArtists(String query) async {
    try {
      return await _currentApi.searchArtists(query);
    } catch (e) {
      _emitError('searchArtists', '搜索歌手失败', e);
      return [];
    }
  }

  Future<List<Album>> searchAlbums(String query) async {
    try {
      return await _currentApi.searchAlbums(query);
    } catch (e) {
      _emitError('searchAlbums', '搜索专辑失败', e);
      return [];
    }
  }

  Future<List<Song>> getTopCharts() async {
    try {
      return await _currentApi.getTopCharts();
    } catch (e) {
      _emitError('getTopCharts', '获取榜单失败', e);
      return [];
    }
  }

  Future<Song?> getSongDetail(String id) async {
    try {
      return await _currentApi.getSongDetail(id);
    } catch (e) {
      _emitError('getSongDetail', '获取歌曲详情失败', e);
      return null;
    }
  }

  Future<Artist?> getArtistDetail(String id) async {
    try {
      return await _currentApi.getArtistDetail(id);
    } catch (e) {
      _emitError('getArtistDetail', '获取歌手详情失败', e);
      return null;
    }
  }
  
  Future<(Artist?, List<Song>)> getArtistDetailWithSongs(String id) async {
    try {
      return await (_currentApi as CustomApi).getArtistDetailWithSongs(id);
    } catch (e) {
      _emitError('getArtistDetailWithSongs', '获取歌手详情失败', e);
      return (null, <Song>[]);
    }
  }

  Future<Album?> getAlbumDetail(String id) async {
    try {
      return await _currentApi.getAlbumDetail(id);
    } catch (e) {
      _emitError('getAlbumDetail', '获取专辑详情失败', e);
      return null;
    }
  }
  
  Future<(Album?, List<Song>)> getAlbumDetailWithTracks(String id) async {
    try {
      return await (_currentApi as CustomApi).getAlbumDetailWithTracks(id);
    } catch (e) {
      _emitError('getAlbumDetailWithTracks', '获取专辑详情失败', e);
      return (null, <Song>[]);
    }
  }

  Future<List<Album>> getArtistAlbums(String artistId) async {
    try {
      return await _currentApi.getArtistAlbums(artistId);
    } catch (e) {
      _emitError('getArtistAlbums', '获取歌手专辑失败', e);
      return [];
    }
  }

  Future<List<Song>> getAlbumTracks(String albumId) async {
    try {
      return await _currentApi.getAlbumTracks(albumId);
    } catch (e) {
      _emitError('getAlbumTracks', '获取专辑歌曲失败', e);
      return [];
    }
  }

  Future<List<Song>> getChartSongs(String chartName) async {
    try {
      return await _currentApi.getChartSongs(chartName);
    } catch (e) {
      _emitError('getChartSongs', '获取榜单歌曲失败', e);
      return [];
    }
  }

  Future<List<Song>> getHotSongs() async {
    try {
      return await _currentApi.getHotSongs();
    } catch (e) {
      _emitError('getHotSongs', '获取热门歌曲失败', e);
      return [];
    }
  }

  Future<List<Artist>> getHotArtists() async {
    try {
      return await _currentApi.getHotArtists();
    } catch (e) {
      _emitError('getHotArtists', '获取热门歌手失败', e);
      return [];
    }
  }

  Future<List<Album>> getNewAlbums() async {
    try {
      return await _currentApi.getNewAlbums();
    } catch (e) {
      _emitError('getNewAlbums', '获取新专辑失败', e);
      return [];
    }
  }

  Future<String?> getSongUrl(String id, {String quality = 'exhigh'}) async {
    try {
      return await _currentApi.getSongUrl(id, quality: quality);
    } catch (e) {
      _emitError('getSongUrl', '获取播放链接失败', e);
      return null;
    }
  }

  Future<String?> getSongLyric(String id) async {
    try {
      return await _currentApi.getSongLyric(id);
    } catch (e) {
      _emitError('getSongLyric', '获取歌词失败', e);
      return null;
    }
  }

  bool isFullAudio(Song song) => _currentApi.isFullAudio(song);

  void dispose() {
    _errorController.close();
  }
}
