import 'package:dio/dio.dart';
import '../features/player/domain/entities/song.dart';

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
  }

  void setSource(MusicSource source) {
    _currentSource = source;
  }

  MusicSource get currentSource => _currentSource;

  Future<List<Song>> searchSongs(String query) async {
    return _searchKuwo(query);
  }

  Future<List<Song>> _searchKuwo(String query) async {
    try {
      final response = await _dio.get(
        '$_kuwoApi/',
        queryParameters: {'name': query, 'page': 1, 'limit': 20},
      );
      
      if (response.data['code'] != 200) {
        return [];
      }
      
      final results = response.data['data'] as List? ?? [];
      return results.map((track) {
        final rid = track['rid'] ?? 0;
        final songUrl = '$_kuwoApi?id=$rid&type=song&level=exhigh&format=mp3';
        
        return Song(
          id: int.tryParse(rid.toString()) ?? DateTime.now().millisecondsSinceEpoch,
          title: track['name']?.toString() ?? 'Unknown',
          artist: track['artist']?.toString() ?? 'Unknown Artist',
          album: track['album']?.toString() ?? 'Kuwo',
          albumArt: track['pic']?.toString(),
          audioUrl: songUrl,
          duration: Duration.zero,
          isLocal: false,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Song>> getTopCharts() async {
    return _searchKuwo('热门歌曲');
  }

  bool isFullAudio(Song song) {
    if (song.audioUrl == null) return false;
    return song.audioUrl!.isNotEmpty;
  }
}
