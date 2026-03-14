import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';
import '../features/player/domain/entities/artist.dart';
import '../features/player/domain/entities/album.dart';

class AppLogger {
  static Function(String)? _logCallback;
  
  static void setLogger(Function(String) callback) {
    _logCallback = callback;
  }
  
  static void log(String message) {
    _logCallback?.call(message);
  }
}

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
  final String _customBaseUrl;
  
  CustomApi(this._customBaseUrl) : _dio = Dio(BaseOptions(
    baseUrl: _customBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    validateStatus: (status) => status! < 500,
  ));

  @override
  String get name => '自定义';

  @override
  String get baseUrl => _customBaseUrl;

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final response = await _dio.get('/search', queryParameters: {'keyword': query});
      
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final results = response.data['data'] as List? ?? [];
        return results.map((track) => _parseSong(track)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('自定义 API 异常: $e');
      return [];
    }
  }

  @override
  Future<List<Song>> getTopCharts() async {
    return searchSongs('热门');
  }

  @override
  Future<List<Artist>> searchArtists(String query) async {
    return [];
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    return [];
  }

  @override
  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return song.audioUrl!.isNotEmpty;
  }

  Song _parseSong(Map<String, dynamic> track) {
    return Song(
      id: track['id'] ?? DateTime.now().millisecondsSinceEpoch,
      title: track['name']?.toString() ?? 'Unknown',
      artist: track['artist']?.toString() ?? 'Unknown Artist',
      album: track['album']?.toString() ?? 'Unknown Album',
      albumArt: track['pic']?.toString(),
      audioUrl: track['url']?.toString(),
      duration: Duration(seconds: track['duration'] ?? 0),
      isLocal: false,
    );
  }
}

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  MusicApi _currentApi = KuwoApi();
  MusicSource _currentSource = MusicSource.kuwo;
  String _customApiUrl = '';

  MusicApiService._() {
    AppLogger.log('MusicApiService 初始化完成');
  }

  void setSource(MusicSource source, {String? customUrl}) {
    _currentSource = source;
    switch (source) {
      case MusicSource.kuwo:
        _currentApi = KuwoApi();
        break;
      case MusicSource.custom:
        _customApiUrl = customUrl ?? '';
        if (_customApiUrl.isNotEmpty) {
          _currentApi = CustomApi(_customApiUrl);
        }
        break;
    }
    AppLogger.log('切换音乐源: ${_currentApi.name}');
  }

  MusicSource get currentSource => _currentSource;
  String get currentApiUrl => _currentApi.baseUrl;
  String get currentApiName => _currentApi.name;

  Future<List<Song>> searchSongs(String query) async {
    AppLogger.log('搜索: $query');
    return _currentApi.searchSongs(query);
  }

  Future<List<Song>> getTopCharts() async {
    AppLogger.log('获取热门歌曲');
    return _currentApi.getTopCharts();
  }

  Future<List<Artist>> searchArtists(String query) async {
    AppLogger.log('搜索歌手: $query');
    return _currentApi.searchArtists(query);
  }

  Future<List<Album>> searchAlbums(String query) async {
    AppLogger.log('搜索专辑: $query');
    return _currentApi.searchAlbums(query);
  }

  bool isFullAudio(Song song) {
    return _currentApi.isFullAudio(song);
  }
}
