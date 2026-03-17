import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';
import '../features/player/domain/entities/artist.dart';
import '../features/player/domain/entities/album.dart';

class AppLogger {
  static Function(String)? _logCallback;
  static void setLogger(Function(String) callback) { _logCallback = callback; }
  static void log(String message) { _logCallback?.call(message); }
}

enum MusicSource { custom }

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
  static const String _apiKey = 'your-secret-api-key';
  static const String _domain = 'https://music-api.codeseek.me:37280';
  
  CustomApi({String? baseUrl}) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl ?? _domain,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    followRedirects: true,
    validateStatus: (status) => status! < 500,
    headers: {'Authorization': 'Bearer $_apiKey', 'Content-Type': 'application/json'},
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
      final response = await _dio.get('/api/v1/search', queryParameters: {'q': query, 'type': 'artist'});
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Album>> searchAlbums(String query) async {
    try {
      final response = await _dio.get('/api/v1/search', queryParameters: {'q': query, 'type': 'album'});
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
      final response = await _dio.get('/api/v1/hot/artists');
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final data = response.data['data'];
        final results = (data is Map) ? (data['list'] as List? ?? []) : (data as List? ?? []);
        return results.map((artist) => Artist(
          id: artist['id']?.toString() ?? '',
          name: artist['name']?.toString() ?? 'Unknown',
          avatar: artist['avatar'] ?? artist['pic'],
          musicNum: artist['musicNum'],
        )).toList();
      }
      return [];
    } catch (e) { return []; }
  }

  @override
  Future<List<Album>> getNewAlbums() async {
    try {
      final response = await _dio.get('/api/v1/new/albums');
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
    return Song(
      id: int.tryParse((track['rid'] ?? track['id']).toString()) ?? DateTime.now().millisecondsSinceEpoch,
      title: track['name']?.toString() ?? track['title']?.toString() ?? 'Unknown',
      artist: track['artist']?.toString() ?? 'Unknown Artist',
      album: track['album']?.toString() ?? 'Unknown Album',
      albumArt: track['pic'] ?? track['albumArt'] ?? track['cover'],
      audioUrl: track['url'] ?? track['audioUrl'],
      duration: Duration(seconds: track['duration'] is int ? track['duration'] : 0),
      isLocal: false,
    );
  }
}

class MusicApiService {
  static MusicApiService? _instance;
  static MusicApiService get instance => _instance ??= MusicApiService._();
  MusicApi _currentApi = CustomApi();
  MusicApiService._();

  void setSource(MusicSource source, {String? customUrl}) {
    _currentApi = CustomApi(baseUrl: customUrl);
  }

  Future<List<Song>> searchSongs(String query) => _currentApi.searchSongs(query);
  Future<List<Artist>> searchArtists(String query) => _currentApi.searchArtists(query);
  Future<List<Album>> searchAlbums(String query) => _currentApi.searchAlbums(query);
  Future<List<Song>> getTopCharts() => _currentApi.getTopCharts();
  Future<Song?> getSongDetail(String id) => _currentApi.getSongDetail(id);
  Future<Artist?> getArtistDetail(String id) => _currentApi.getArtistDetail(id);
  Future<Album?> getAlbumDetail(String id) => _currentApi.getAlbumDetail(id);
  Future<List<Album>> getArtistAlbums(String artistId) => _currentApi.getArtistAlbums(artistId);
  Future<List<Song>> getAlbumTracks(String albumId) => _currentApi.getAlbumTracks(albumId);
  Future<List<Song>> getChartSongs(String chartName) => _currentApi.getChartSongs(chartName);
  Future<List<Song>> getHotSongs() => _currentApi.getHotSongs();
  Future<List<Artist>> getHotArtists() => _currentApi.getHotArtists();
  Future<List<Album>> getNewAlbums() => _currentApi.getNewAlbums();
  Future<String?> getSongUrl(String id, {String quality = 'exhigh'}) => _currentApi.getSongUrl(id, quality: quality);
  Future<String?> getSongLyric(String id) => _currentApi.getSongLyric(id);
  bool isFullAudio(Song song) => _currentApi.isFullAudio(song);
}
