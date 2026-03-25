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
  Future<List<Song>> getTopTracks({int limit = 20});
  Future<List<Artist>> getHotArtists();
  Future<List<Artist>> getTopArtists({int limit = 20});
  Future<String?> getSongUrl(String id, {String quality = 'exhigh'});
  Future<String?> getSongLyric(String id);
  Future<List<Song>> getSimilarSongs(String id, {int limit = 20});
  Future<List<Song>> getSimilarSongsByKeyword(String track, String artist, {int limit = 20});
  Future<List<Artist>> getSimilarArtists(String id, {int limit = 10});
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
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('Found ${results.length} artists for query: $query');
        
        return results.map((item) => Artist(
          id: item['rid']?.toString() ?? item['id']?.toString() ?? '',
          name: item['artist']?.toString() ?? item['name']?.toString() ?? 'Unknown',
          avatar: item['albumArt']?.toString() ?? item['avatar']?.toString() ?? item['pic']?.toString(),
          musicNum: item['musicNum'] is int ? item['musicNum'] : int.tryParse(item['musicNum']?.toString() ?? '0'),
        )).toList();
      }
      AppLogger.log('Search artists failed: code=${response.data['code']}');
      return [];
    } on DioException catch (e) {
      AppLogger.log('Search artists network error: ${e.type} - ${e.message}');
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
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        AppLogger.log('Found ${results.length} albums for query: $query');
        
        return results.map((item) => Album(
          id: item['rid']?.toString() ?? item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Unknown',
          artist: item['artist']?.toString(),
          cover: item['albumArt']?.toString() ?? item['cover']?.toString() ?? item['pic']?.toString(),
        )).toList();
      }
      AppLogger.log('Search albums failed: code=${response.data['code']}');
      return [];
    } on DioException catch (e) {
      AppLogger.log('Search albums network error: ${e.type} - ${e.message}');
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

  @override
  Future<List<Song>> getTopCharts() async {
    try {
      final chartsResponse = await _dio.get('/api/v1/ytm/charts');
      if (chartsResponse.statusCode == 200 && chartsResponse.data['code'] == 200) {
        final chartsList = chartsResponse.data['data']?['list'] as List? ?? [];
        if (chartsList.isNotEmpty) {
          String playlistId = chartsList[0]['id']?.toString() ?? '';
          if (playlistId.startsWith('Y-')) {
            playlistId = playlistId.substring(2);
          }
          final response = await _dio.get('/api/v1/ytm/playlist/$playlistId', queryParameters: {'limit': 50});
          if (response.statusCode == 200 && response.data['code'] == 200) {
            final data = response.data['data'];
            final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
            return results.map((track) => _parseSong(track)).toList();
          }
        }
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Song>> getTopTracks({int limit = 20}) async {
    try {
      final chartsResponse = await _dio.get('/api/v1/ytm/charts');
      if (chartsResponse.statusCode == 200 && chartsResponse.data['code'] == 200) {
        final chartsList = chartsResponse.data['data']?['list'] as List? ?? [];
        if (chartsList.isNotEmpty) {
          String playlistId = chartsList[0]['id']?.toString() ?? '';
          if (playlistId.startsWith('Y-')) {
            playlistId = playlistId.substring(2);
          }
          final response = await _dio.get('/api/v1/ytm/playlist/$playlistId', queryParameters: {'limit': limit});
          if (response.statusCode == 200 && response.data['code'] == 200) {
            final data = response.data['data'];
            final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
            return results.map((track) => _parseSong(track)).toList();
          }
        }
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Artist>> getHotArtists() async {
    try {
      final response = await _dio.get('/api/v1/ytm/home');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final sections = response.data['data']?['sections'] as List? ?? [];
        final seenArtists = <String>{};
        final artists = <Artist>[];
        
        for (final section in sections) {
          final content = section['content'] as List? ?? [];
          for (final item in content) {
            final artistName = item['artist']?.toString() ?? '';
            if (artistName.isNotEmpty && !seenArtists.contains(artistName) && artists.length < 20) {
              seenArtists.add(artistName);
              artists.add(Artist(
                id: item['rid']?.toString() ?? '',
                name: artistName,
                avatar: item['albumArt']?.toString(),
              ));
            }
          }
          if (artists.length >= 20) break;
        }
        return artists;
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Artist>> getTopArtists({int limit = 20}) async {
    try {
      final response = await _dio.get('/api/v1/ytm/home');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final sections = response.data['data']?['sections'] as List? ?? [];
        final seenArtists = <String>{};
        final artists = <Artist>[];
        
        for (final section in sections) {
          final content = section['content'] as List? ?? [];
          for (final item in content) {
            final artistName = item['artist']?.toString() ?? '';
            if (artistName.isNotEmpty && !seenArtists.contains(artistName) && artists.length < limit) {
              seenArtists.add(artistName);
              artists.add(Artist(
                id: item['rid']?.toString() ?? '',
                name: artistName,
                avatar: item['albumArt']?.toString(),
              ));
            }
          }
          if (artists.length >= limit) break;
        }
        return artists;
      }
      return [];
    } catch (e) { return []; }
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

  @override
  Future<List<Song>> getSimilarSongs(String id, {int limit = 20}) async {
    try {
      String videoId = id;
      if (videoId.startsWith('Y-')) {
        videoId = videoId.substring(2);
      }
      final response = await _dio.get('/api/v1/ytm/related/$videoId', queryParameters: {'limit': limit});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final list = response.data['data']?['list'] as List? ?? [];
        return list.map((item) => Song(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: item['name']?.toString() ?? 'Unknown',
          artist: item['artist']?.toString() ?? 'Unknown Artist',
          album: '',
          albumArt: item['albumArt']?.toString(),
          duration: Duration(seconds: item['duration'] ?? 0),
          isLocal: false,
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('getSimilarSongs error: $e');
      return [];
    }
  }

  Future<Song?> matchSong(String name, String artist) async {
    try {
      final response = await _dio.get('/api/v1/song/match', queryParameters: {'name': name, 'artist': artist});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        return _parseSong(response.data['data']);
      }
      return null;
    } catch (e) {
      AppLogger.log('matchSong error: $e');
      return null;
    }
  }

  Future<List<Song>> getSimilarSongsByKeyword(String track, String artist, {int limit = 20}) async {
    try {
      final searchResponse = await _dio.get('/api/v1/ytm/search', queryParameters: {'q': '$track $artist', 'limit': 1});
      if (searchResponse.statusCode == 200 && searchResponse.data['code'] == 200) {
        final searchList = searchResponse.data['data']?['list'] as List? ?? [];
        if (searchList.isNotEmpty) {
          String videoId = searchList[0]['rid']?.toString() ?? '';
          if (videoId.startsWith('Y-')) {
            videoId = videoId.substring(2);
          }
          final response = await _dio.get('/api/v1/ytm/related/$videoId', queryParameters: {'limit': limit});
          if (response.statusCode == 200 && response.data['code'] == 200) {
            final list = response.data['data']?['list'] as List? ?? [];
            return list.map((item) => Song(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: item['name']?.toString() ?? 'Unknown',
              artist: item['artist']?.toString() ?? 'Unknown Artist',
              album: '',
              albumArt: item['albumArt']?.toString(),
              duration: Duration(seconds: item['duration'] ?? 0),
              isLocal: false,
            )).toList();
          }
        }
      }
      return [];
    } catch (e) {
      AppLogger.log('getSimilarSongsByKeyword error: $e');
      return [];
    }
  }

  Future<List<Artist>> getSimilarArtists(String id, {int limit = 10}) async {
    try {
      final response = await _dio.get('/api/v1/artist/$id/similar', queryParameters: {'limit': limit});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((item) => Artist(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Unknown',
          avatar: item['avatar']?.toString(),
          musicNum: item['musicNum'] is int ? item['musicNum'] : int.tryParse(item['musicNum']?.toString() ?? '0'),
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('getSimilarArtists error: $e');
      return [];
    }
  }

  Future<List<Song>> getTagTracks(String tag, {int limit = 20}) async {
    try {
      final response = await _dio.get('/api/v1/tag/$tag/tracks', queryParameters: {'limit': limit});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  Future<List<Song>> getGeoTracks(String country, {int limit = 20}) async {
    try {
      final response = await _dio.get('/api/v1/geo/$country/tracks', queryParameters: {'limit': limit});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) { return []; }
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
      id: (track['rid'] ?? track['id'])?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: track['name']?.toString() ?? track['title']?.toString() ?? 'Unknown',
      artist: track['artist']?.toString() ?? 'Unknown Artist',
      album: track['album']?.toString() ?? 'Unknown Album',
      albumArt: track['albumArt'] ?? track['pic'] ?? track['cover'],
      audioUrl: track['url'] ?? track['audioUrl'],
      duration: duration,
      isLocal: false,
    );
  }

  Song _parseSimilarSong(Map<String, dynamic> item) {
    final durationValue = item['duration'];
    Duration duration;
    
    if (durationValue is int && durationValue > 0) {
      if (durationValue > 10000) {
        duration = Duration(milliseconds: durationValue);
      } else {
        duration = Duration(seconds: durationValue);
      }
    } else {
      duration = Duration.zero;
    }
    
    return Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: item['name']?.toString() ?? 'Unknown',
      artist: item['artist']?.toString() ?? 'Unknown Artist',
      album: item['album']?.toString() ?? 'Unknown Album',
      albumArt: item['albumArt'],
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

  Future<List<Song>> getTopTracks({int limit = 20}) async {
    try {
      return await _currentApi.getTopTracks(limit: limit);
    } catch (e) {
      _emitError('getTopTracks', '获取热门歌曲失败', e);
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

  Future<List<Artist>> getTopArtists({int limit = 20}) async {
    try {
      return await _currentApi.getTopArtists(limit: limit);
    } catch (e) {
      _emitError('getTopArtists', '获取全球热门歌手失败', e);
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

  Future<List<Song>> getSimilarSongs(String id, {int limit = 20}) async {
    try {
      return await _currentApi.getSimilarSongs(id, limit: limit);
    } catch (e) {
      _emitError('getSimilarSongs', '获取相似歌曲失败', e);
      return [];
    }
  }

  Future<Song?> matchSong(String name, String artist) async {
    try {
      return await (_currentApi as CustomApi).matchSong(name, artist);
    } catch (e) {
      _emitError('matchSong', '匹配歌曲失败', e);
      return null;
    }
  }

  Future<List<Song>> getSimilarSongsByKeyword(String track, String artist, {int limit = 20}) async {
    try {
      return await (_currentApi as CustomApi).getSimilarSongsByKeyword(track, artist, limit: limit);
    } catch (e) {
      _emitError('getSimilarSongsByKeyword', '获取相似歌曲失败', e);
      return [];
    }
  }

  Future<List<Artist>> getSimilarArtists(String id, {int limit = 10}) async {
    try {
      return await (_currentApi as CustomApi).getSimilarArtists(id, limit: limit);
    } catch (e) {
      _emitError('getSimilarArtists', '获取相似歌手失败', e);
      return [];
    }
  }

  Future<List<Song>> getTagTracks(String tag, {int limit = 20}) async {
    try {
      return await (_currentApi as CustomApi).getTagTracks(tag, limit: limit);
    } catch (e) {
      _emitError('getTagTracks', '获取标签歌曲失败', e);
      return [];
    }
  }

  Future<List<Song>> getGeoTracks(String country, {int limit = 20}) async {
    try {
      return await (_currentApi as CustomApi).getGeoTracks(country, limit: limit);
    } catch (e) {
      _emitError('getGeoTracks', '获取地区歌曲失败', e);
      return [];
    }
  }

  bool isFullAudio(Song song) => _currentApi.isFullAudio(song);

  void dispose() {
    _errorController.close();
  }
}
