import 'package:dio/dio.dart';
import 'package:music_app/core/utils/app_logger.dart';
import '../features/player/domain/entities/song.dart';
import '../features/player/domain/entities/artist.dart';
import '../features/player/domain/entities/album.dart';

enum MusicSource {
  kuwo,
  custom,
}

abstract class MusicApi {
  String get name;
  String get baseUrl;
  Future<List<Song>> searchSongs(String query);
  Future<List<Artist>> searchArtists(String query);
  Future<List<Album>> searchAlbums(String query);
  Future<List<Song>> getTopCharts();
  bool isFullAudio(Song song);
}

class KuwoApi implements MusicApi {
  final Dio _dio;
  
  KuwoApi() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    validateStatus: (status) => status! < 500,
  ));

  @override
  String get name => '酷我音乐';

  @override
  String get baseUrl => 'https://kw-api.cenguigui.cn';

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      AppLogger.log('开始请求 Kuwo API...');
      
      final response = await _dio.get(
        '$baseUrl/',
        queryParameters: {'name': query, 'page': 1, 'limit': 20},
      );
      
      AppLogger.log('Kuwo API 响应: ${response.statusCode}');
      
      if (response.data['code'] != 200) {
        AppLogger.log('Kuwo API 错误: ${response.data}');
        return [];
      }
      
      final results = response.data['data'] as List? ?? [];
      AppLogger.log('获取到 ${results.length} 首歌曲');
      
      return results.map((track) {
        final rid = track['rid'] ?? 0;
        final name = track['name']?.toString() ?? 'Unknown';
        final artist = track['artist']?.toString() ?? 'Unknown Artist';
        final album = track['album']?.toString() ?? 'Kuwo';
        final pic = track['pic']?.toString();
        
        AppLogger.log('歌曲: name=$name, artist=$artist, album=$album');
        
        final songUrl = '$baseUrl?id=$rid&type=song&level=exhigh&format=mp3';
        
        final durationSec = track['duration'] is int 
            ? track['duration'] 
            : int.tryParse(track['duration']?.toString() ?? '0') ?? 0;
        
        final song = Song(
          id: int.tryParse(rid.toString()) ?? DateTime.now().millisecondsSinceEpoch,
          title: name,
          artist: artist,
          album: album,
          albumArt: pic,
          audioUrl: songUrl,
          duration: Duration(seconds: durationSec),
          isLocal: false,
        );
        
        AppLogger.log('Song created: ${song.title} - ${song.artist}');
        return song;
      }).toList();
    } catch (e) {
      AppLogger.log('Kuwo API 异常: $e');
      return [];
    }
  }

  @override
  Future<List<Song>> getTopCharts() async {
    return searchSongs('热门歌曲');
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    try {
      final response = await _dio.get(
        '$baseUrl/',
        queryParameters: {'name': query, 'type': 'artist', 'limit': 20},
      );
      
      if (response.data['code'] != 200) {
        return [];
      }
      
      final results = response.data['data'] as List? ?? [];
      return results.map((e) => Artist.fromJson(e)).toList();
    } catch (e) {
      AppLogger.log('Kuwo API searchArtists 异常: $e');
      return [];
    }
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    try {
      // Search songs first, then extract unique albums
      final songs = await searchSongs(query);
      final albumMap = <String, Album>{};
      
      for (var song in songs) {
        if (song.album.isNotEmpty && !albumMap.containsKey(song.album)) {
          albumMap[song.album] = Album(
            id: song.id.toString(),
            name: song.album,
            artist: song.artist,
            cover: song.albumArt,
          );
        }
      }
      
      return albumMap.values.toList();
    } catch (e) {
      AppLogger.log('Kuwo API searchAlbums 异常: $e');
      return [];
    }
  }

  @override
  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return song.audioUrl!.isNotEmpty;
  }
}

class CustomApi implements MusicApi {
  final Dio _dio;
  static const String _apiKey = 'your-secret-api-key';
  static const String _domain = 'https://music-api.codeseek.me:37280';
  
  CustomApi({String? baseUrl}) 
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? _domain,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          followRedirects: true,
          validateStatus: (status) => status! < 500,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ));

  @override
  String get name => '自定义 API';

  @override
  String get baseUrl => _dio.options.baseUrl!;

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      AppLogger.log('搜索歌曲：$query');
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': query, 'type': 'song'},
      );
      AppLogger.log('搜索响应：${response.statusCode}');
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        AppLogger.log('获取到 ${results.length} 首歌曲');
        return results.map((track) => _parseSong(track)).toList();
      }
      AppLogger.log('搜索失败：${response.data}');
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 搜索歌曲失败：$e');
      return [];
    }
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    try {
      AppLogger.log('搜索艺人：$query');
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': query, 'type': 'artist'},
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 搜索艺人失败：$e');
      return [];
    }
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    try {
      AppLogger.log('搜索专辑：$query');
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': query, 'type': 'album'},
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((album) => Album(
          id: album['id']?.toString() ?? '',
          name: album['name']?.toString() ?? 'Unknown',
          artist: album['artist']?.toString(),
          cover: album['cover'] ?? album['pic'],
          
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 搜索专辑失败：$e');
      return [];
    }
  }

  @override
  Future<List<Song>> getTopCharts() async {
    return getHotSongs();
  }

  @override
  Future<List<Song>> getHotSongs() async {
    try {
      AppLogger.log('获取热门歌曲');
      // 使用搜索接口获取热门歌曲
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': '热门', 'type': 'song'},
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 获取热门歌曲失败：$e');
      return [];
    }
  }

  @override
  Future<List<Artist>> getHotArtists() async {
    try {
      AppLogger.log('获取热门艺人');
      // 使用搜索接口获取热门艺人
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': '热门', 'type': 'artist'},
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 获取热门艺人失败：$e');
      return [];
    }
  }


  @override
  Future<List<Album>> getNewAlbums() async {
    try {
      AppLogger.log('获取新专辑');
      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: {'q': '最新', 'type': 'album'},
      );
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((album) => Album(
          id: album['id']?.toString() ?? '',
          name: album['name']?.toString() ?? 'Unknown',
          artist: album['artist']?.toString(),
          cover: album['cover'] ?? album['pic'],
        )).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 获取新专辑失败：$e');
      return [];
    }
  }

  @override
  bool isFullAudio(Song song) {
    return song.duration.inSeconds > 60;
  }

  Song _parseSong(Map<String, dynamic> track) {
    final rid = track['rid'] ?? track['id'] ?? 0;
    final name = track['name']?.toString() ?? track['title']?.toString() ?? 'Unknown';
    final artist = track['artist']?.toString() ?? track['artist_name'] ?? 'Unknown Artist';
    final album = track['album']?.toString() ?? track['album_name'] ?? 'Unknown Album';
    final pic = track['pic'] ?? track['albumArt'] ?? track['cover'];
    
    final durationSec = track['duration'] is int 
        ? track['duration'] 
        : int.tryParse(track['duration']?.toString() ?? '0') ?? 0;
    
    return Song(
      id: int.tryParse(rid.toString()) ?? DateTime.now().millisecondsSinceEpoch,
      title: name,
      artist: artist,
      album: album,
      albumArt: pic,
      audioUrl: track['audioUrl'] ?? track['url'],
      duration: Duration(seconds: durationSec),
      isLocal: false,
    );
  }
}

class MusicApiService {
  static MusicApiService? _instance;
  static MusicApiService get instance => _instance ??= MusicApiService._();

  MusicApi _currentApi = CustomApi();
  MusicSource _currentSource = MusicSource.custom;

  MusicApiService._();

  void setSource(MusicSource source, {String? customUrl}) {
    _currentSource = source;

    switch (source) {
      case MusicSource.kuwo:
        _currentApi = KuwoApi();
        break;
      case MusicSource.custom:
        _currentApi = CustomApi(baseUrl: customUrl);
        break;
    }
    AppLogger.log('切换音乐源：${source.name}');
  }

  Future<T> _withReadFallback<T>(
    String action,
    Future<T> Function(MusicApi api) request,
  ) async {
    try {
      final result = await request(_currentApi);
      if (_shouldFallback(result)) {
        return await _tryKuwoFallback(action, request, 'empty result');
      }
      return result;
    } catch (e) {
      return await _tryKuwoFallback(action, request, e);
    }
  }

  bool _shouldFallback(Object? result) {
    return _currentSource == MusicSource.custom && result is List && result.isEmpty;
  }

  Future<T> _tryKuwoFallback<T>(
    String action,
    Future<T> Function(MusicApi api) request,
    Object reason,
  ) async {
    if (_currentSource != MusicSource.custom) {
      rethrow;
    }

    AppLogger.log('自定义 API $action 失败，尝试回退到 Kuwo：$reason');

    try {
      final fallbackApi = KuwoApi();
      final fallbackResult = await request(fallbackApi);
      if (fallbackResult is List) {
        AppLogger.log('Kuwo 回退 $action 成功，返回 ${fallbackResult.length} 条数据');
      } else {
        AppLogger.log('Kuwo 回退 $action 成功');
      }
      return fallbackResult;
    } catch (fallbackError) {
      AppLogger.log('Kuwo 回退 $action 也失败：$fallbackError');
      rethrow;
    }
  }

  Future<List<Song>> searchSongs(String query) =>
      _withReadFallback('searchSongs($query)', (api) => api.searchSongs(query));

  Future<List<Artist>> searchArtists(String query) =>
      _withReadFallback('searchArtists($query)', (api) => api.searchArtists(query));

  Future<List<Album>> searchAlbums(String query) =>
      _withReadFallback('searchAlbums($query)', (api) => api.searchAlbums(query));

  Future<List<Song>> getTopCharts() =>
      _withReadFallback('getTopCharts', (api) => api.getTopCharts());

  bool isFullAudio(Song song) => _currentApi.isFullAudio(song);
}
