import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';

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
}

class MusicApiService {
  static final MusicApiService _instance = MusicApiService._();
  static MusicApiService get instance => _instance;
  
  late Dio _dio;
  MusicSource _currentSource = MusicSource.kuwo;

  static const String _kuwoApi = 'https://kw-api.cenguigui.cn';

  MusicApiService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
      validateStatus: (status) => status! < 500,
    ));
    
    AppLogger.log('MusicApiService 初始化完成');
  }

  void setSource(MusicSource source) {
    _currentSource = source;
  }

  MusicSource get currentSource => _currentSource;

  Future<List<Song>> searchSongs(String query) async {
    AppLogger.log('搜索: $query');
    return _searchKuwo(query);
  }

  Future<List<Song>> _searchKuwo(String query) async {
    try {
      AppLogger.log('开始请求 Kuwo API...');
      
      final response = await _dio.get(
        '$_kuwoApi/',
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
        
        final songUrl = '$_kuwoApi?id=$rid&type=song&level=exhigh&format=mp3';
        
        final song = Song(
          id: int.tryParse(rid.toString()) ?? DateTime.now().millisecondsSinceEpoch,
          title: name,
          artist: artist,
          album: album,
          albumArt: pic,
          audioUrl: songUrl,
          duration: Duration.zero,
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

  Future<List<Song>> getTopCharts() async {
    AppLogger.log('获取热门歌曲');
    return _searchKuwo('热门歌曲');
  }

  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return song.audioUrl!.isNotEmpty;
  }
}
