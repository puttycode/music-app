import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/services/curated_recommendations.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/core/utils/app_logger.dart';

// 每日推荐主题配置 - 高质量、有内涵、有品位的推荐
class DailyRecommendationTheme {
  final String name;
  final List<String> artists;
  final List<String> genres;
  final List<String> moods;
  final String description;

  const DailyRecommendationTheme({
    required this.name,
    required this.artists,
    required this.genres,
    required this.moods,
    required this.description,
  });
}

// 每日主题轮播 - 7天一个周期，每天都有不同风格
final List<DailyRecommendationTheme> weeklyThemes = [
  // 周一：爵士与灵魂乐 - 优雅从容的开始
  DailyRecommendationTheme(
    name: '爵士时光',
    description: '用优雅的爵士乐开启新的一周',
    artists: ['Miles Davis', 'John Coltrane', 'Billie Holiday', 'Norah Jones', 'Diana Krall', '陈绮贞', '王若琳'],
    genres: ['爵士', '灵魂乐', '蓝调'],
    moods: ['优雅', '放松', '沉思'],
  ),
  // 周二：华语独立 - 原创力量
  DailyRecommendationTheme(
    name: '华语独立',
    description: '发现华语独立音乐的魅力',
    artists: ['万能青年旅店', '草东没有派对', 'deca joins', '椅子乐团', '告五人', '声音玩具', '惘闻'],
    genres: ['华语独立', '独立摇滚', '后摇'],
    moods: ['深沉', '文艺', '独特'],
  ),
  // 周三：独立民谣 - 诗意生活
  DailyRecommendationTheme(
    name: '诗意民谣',
    description: '用音乐书写生活的诗篇',
    artists: ['Bob Dylan', 'Damien Rice', '张悬', '陈粒', '赵雷', '朴树', '李健', '雷光夏'],
    genres: ['民谣', '独立音乐', '创作歌手'],
    moods: ['诗意', '怀旧', '温暖'],
  ),
  // 周四：华语经典 - 回忆时光
  DailyRecommendationTheme(
    name: '华语经典',
    description: '聆听华语音乐的黄金时代',
    artists: ['王菲', '张国荣', '张学友', '陈奕迅', '林忆莲', '李宗盛', '邓丽君', '罗大佑'],
    genres: ['华语经典', '港台金曲', '华语流行'],
    moods: ['怀旧', '经典', '感动'],
  ),
  // 周五：摇滚与独立 - 释放能量
  DailyRecommendationTheme(
    name: '独立之声',
    description: '为即将到来的周末预热',
    artists: ['Radiohead', 'Arcade Fire', '万能青年旅店', '草东没有派对', 'deca joins', '椅子乐团', '告五人'],
    genres: ['独立摇滚', '另类', '后朋克'],
    moods: ['活力', '自由', '释放'],
  ),
  // 周六：世界音乐 - 环球之旅
  DailyRecommendationTheme(
    name: '世界之声',
    description: '用音乐环游世界',
    artists: ['A.R. Rahman', 'Caetano Veloso', 'Angélique Kidjo', 'Ravi Shankar', '杭盖乐队', '九宝乐队', '朱哲琴'],
    genres: ['世界音乐', '民族融合', '传统现代'],
    moods: ['探索', '异域', '热情'],
  ),
  // 周日：轻松流行 - 温柔收尾
  DailyRecommendationTheme(
    name: '周日慢时光',
    description: '用温柔的声音结束一周',
    artists: ['Adele', 'Coldplay', 'Ed Sheeran', '徐佳莹', '魏如萱', '孙燕姿', '方大同', '卢广仲'],
    genres: ['流行', 'R&B', '抒情'],
    moods: ['温柔', '治愈', '希望'],
  ),
];

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {}

class AddToRecentPlays extends HomeEvent {
  final Song song;
  const AddToRecentPlays(this.song);

  @override
  List<Object?> get props => [song];
}

class HomeState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Song> recentPlays;
  final List<Song> topCharts;
  final List<Song> recommendations;
  final List<Artist> hotArtists;
  final List<Album> newAlbums;
  final String? dailyThemeName;
  final String? dailyThemeDescription;

  const HomeState({
    this.isLoading = false,
    this.error,
    this.recentPlays = const [],
    this.topCharts = const [],
    this.recommendations = const [],
    this.hotArtists = const [],
    this.newAlbums = const [],
    this.dailyThemeName,
    this.dailyThemeDescription,
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? recentPlays,
    List<Song>? topCharts,
    List<Song>? recommendations,
    List<Artist>? hotArtists,
    List<Album>? newAlbums,
    String? dailyThemeName,
    String? dailyThemeDescription,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recentPlays: recentPlays ?? this.recentPlays,
      topCharts: topCharts ?? this.topCharts,
      recommendations: recommendations ?? this.recommendations,
      hotArtists: hotArtists ?? this.hotArtists,
      newAlbums: newAlbums ?? this.newAlbums,
      dailyThemeName: dailyThemeName ?? this.dailyThemeName,
      dailyThemeDescription: dailyThemeDescription ?? this.dailyThemeDescription,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, recentPlays, topCharts, recommendations, hotArtists, newAlbums, dailyThemeName, dailyThemeDescription];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final MusicApiService _apiService = MusicApiService.instance;

  HomeBloc() : super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<AddToRecentPlays>(_onAddToRecentPlays);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));

    final recentSongs = <Song>[];

    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      recentSongs.addAll(recentBox.values.map((e) {
        if (e is Map) {
          return Song.fromLocal(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>());
    } catch (e) {
      AppLogger.log('Load recent plays failed: $e');
    }

    final results = await Future.wait([
      _apiService.getTopCharts().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.log('getTopCharts() timed out');
          return <Song>[];
        },
      ).catchError((_) => <Song>[]),
      _loadYtmHomeContent().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.log('_loadYtmHomeContent() timed out');
          return (<Song>[], <Artist>[], <Album>[]);
        },
      ).catchError((_) => (<Song>[], <Artist>[], <Album>[])),
    ]);

    final topCharts = results[0] as List<Song>;
    final homeContent = results[1] as (List<Song>, List<Artist>, List<Album>);
    final recommendations = homeContent.$1;
    final hotArtists = homeContent.$2;
    final newAlbums = homeContent.$3;

    AppLogger.log('Loaded: ${topCharts.length} charts, ${recommendations.length} recs, ${hotArtists.length} artists, ${newAlbums.length} albums');

    final hasAnyData = recentSongs.isNotEmpty || 
                       topCharts.isNotEmpty || 
                       recommendations.isNotEmpty ||
                       hotArtists.isNotEmpty ||
                       newAlbums.isNotEmpty;

    final theme = _getTodayTheme();

    emit(state.copyWith(
      isLoading: false,
      error: hasAnyData ? null : '暂无数据',
      recentPlays: recentSongs,
      topCharts: topCharts,
      recommendations: recommendations,
      hotArtists: hotArtists,
      newAlbums: newAlbums,
      dailyThemeName: theme.name,
      dailyThemeDescription: theme.description,
    ));
  }

  // 获取当前日期的主题
  DailyRecommendationTheme _getTodayTheme() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1=Monday, 7=Sunday
    return weeklyThemes[dayOfWeek - 1];
  }

  /// 从 YTM Home 获取推荐内容（歌曲、艺人、专辑）
  Future<(List<Song>, List<Artist>, List<Album>)> _loadYtmHomeContent() async {
    try {
      final response = await _apiService.getYtmHome();
      if (response == null) return (<Song>[], <Artist>[], <Album>[]);

      final sections = response['sections'] as List? ?? [];
      final songs = <Song>[];
      final artists = <Artist>[];
      final albums = <Album>[];
      final seenSongIds = <String>{};
      final seenArtistNames = <String>{};

      for (final section in sections) {
        final content = section['content'] as List? ?? [];
        for (final item in content) {
          // 解析歌曲
          if (songs.length < 20) {
            final songId = item['rid']?.toString() ?? '';
            if (songId.isNotEmpty && !seenSongIds.contains(songId)) {
              seenSongIds.add(songId);
              final durationValue = item['duration'];
              Duration duration = Duration.zero;
              if (durationValue is int && durationValue > 0) {
                duration = durationValue > 10000 
                    ? Duration(milliseconds: durationValue) 
                    : Duration(seconds: durationValue);
              }
              songs.add(Song(
                id: songId,
                title: item['name']?.toString() ?? 'Unknown',
                artist: item['artist']?.toString() ?? 'Unknown Artist',
                album: item['album']?.toString() ?? '',
                albumArt: item['albumArt']?.toString(),
                duration: duration,
                isLocal: false,
              ));
            }
          }

          // 解析艺人
          final artistName = item['artist']?.toString() ?? '';
          if (artistName.isNotEmpty && !seenArtistNames.contains(artistName) && artists.length < 20) {
            seenArtistNames.add(artistName);
            artists.add(Artist(
              id: item['rid']?.toString() ?? '',
              name: artistName,
              avatar: item['albumArt']?.toString(),
            ));
          }

          // 解析专辑
          final albumName = item['album']?.toString() ?? '';
          if (albumName.isNotEmpty && albums.length < 10) {
            final albumId = item['rid']?.toString() ?? '';
            if (albumId.isNotEmpty && !albums.any((a) => a.id == albumId)) {
              albums.add(Album(
                id: albumId,
                name: albumName,
                artist: artistName,
                cover: item['albumArt']?.toString(),
              ));
            }
          }
        }
        if (songs.length >= 20 && artists.length >= 20 && albums.length >= 10) break;
      }

      return (songs.take(15).toList(), artists.take(10).toList(), albums.take(6).toList());
    } catch (e) {
      AppLogger.log('_loadYtmHomeContent error: $e');
      return (<Song>[], <Artist>[], <Album>[]);
    }
  }

  Future<void> _onAddToRecentPlays(AddToRecentPlays event, Emitter<HomeState> emit) async {
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      
      // Remove existing song with same ID
      final existingKeys = recentBox.keys.where((key) {
        final item = recentBox.get(key);
        if (item is Map) {
          return item['id']?.toString() == event.song.id;
        }
        return false;
      }).toList();
      for (var key in existingKeys) {
        await recentBox.delete(key);
      }
      
      // Save as JSON
      await recentBox.put(event.song.hashCode, event.song.toJson());
      
      if (recentBox.length > AppConstants.recentPlaysMax) {
        final keys = recentBox.keys.toList();
        await recentBox.delete(keys.first);
      }
      
      final recentSongs = recentBox.values.map((e) {
        if (e is Map) {
          return Song.fromLocal(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>().toList();
      emit(state.copyWith(recentPlays: recentSongs));
    } catch (e) {
      AppLogger.log('Error adding to recent: $e');
    }
  }
}
