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

// 高质量热门歌手库 - 涵盖不同风格、有艺术成就的艺人（100位，华语占50位）
final List<Map<String, String>> curatedHotArtists = [
  // 华语经典（20位）
  {'name': '王菲', 'category': '华语经典'},
  {'name': '张学友', 'category': '华语经典'},
  {'name': '陈奕迅', 'category': '华语经典'},
  {'name': '林忆莲', 'category': '华语经典'},
  {'name': '李宗盛', 'category': '华语经典'},
  {'name': '张国荣', 'category': '华语经典'},
  {'name': '邓丽君', 'category': '华语经典'},
  {'name': '罗大佑', 'category': '华语经典'},
  {'name': '齐秦', 'category': '华语经典'},
  {'name': '周华健', 'category': '华语经典'},
  {'name': '孙燕姿', 'category': '华语经典'},
  {'name': '蔡琴', 'category': '华语经典'},
  {'name': '费玉清', 'category': '华语经典'},
  {'name': '凤飞飞', 'category': '华语经典'},
  {'name': '刘若英', 'category': '华语经典'},
  {'name': '伍佰', 'category': '华语经典'},
  {'name': '张惠妹', 'category': '华语经典'},
  {'name': '那英', 'category': '华语经典'},
  {'name': '张信哲', 'category': '华语经典'},
  {'name': '莫文蔚', 'category': '华语经典'},
  // 华语独立/摇滚（15位）
  {'name': '万能青年旅店', 'category': '华语独立'},
  {'name': '草东没有派对', 'category': '华语独立'},
  {'name': 'deca joins', 'category': '华语独立'},
  {'name': '椅子乐团', 'category': '华语独立'},
  {'name': '告五人', 'category': '华语独立'},
  {'name': '声音玩具', 'category': '华语独立'},
  {'name': '惘闻', 'category': '华语独立'},
  {'name': '新裤子', 'category': '华语独立'},
  {'name': '痛仰', 'category': '华语独立'},
  {'name': '刺猬', 'category': '华语独立'},
  {'name': '达达乐队', 'category': '华语独立'},
  {'name': '后海大鲨鱼', 'category': '华语独立'},
  {'name': '重塑雕像的权利', 'category': '华语独立'},
  {'name': '旅行团', 'category': '华语独立'},
  {'name': '海龟先生', 'category': '华语独立'},
  // 华语创作/民谣（15位）
  {'name': '陈绮贞', 'category': '华语创作'},
  {'name': '张悬', 'category': '华语创作'},
  {'name': '陈粒', 'category': '华语创作'},
  {'name': '赵雷', 'category': '华语创作'},
  {'name': '朴树', 'category': '华语创作'},
  {'name': '李健', 'category': '华语创作'},
  {'name': '许巍', 'category': '华语创作'},
  {'name': '宋冬野', 'category': '华语创作'},
  {'name': '尧十三', 'category': '华语创作'},
  {'name': '苏打绿', 'category': '华语创作'},
  {'name': '魏如萱', 'category': '华语创作'},
  {'name': '徐佳莹', 'category': '华语创作'},
  {'name': '方大同', 'category': '华语创作'},
  {'name': '卢广仲', 'category': '华语创作'},
  {'name': '雷光夏', 'category': '华语创作'},
  // 华语流行（5位）
  {'name': '周杰伦', 'category': '华语流行'},
  {'name': '林俊杰', 'category': '华语流行'},
  {'name': '王力宏', 'category': '华语流行'},
  {'name': '陶喆', 'category': '华语流行'},
  {'name': '蔡依林', 'category': '华语流行'},
  // 欧美经典摇滚（10位）
  {'name': 'The Beatles', 'category': '欧美经典'},
  {'name': 'Pink Floyd', 'category': '欧美经典'},
  {'name': 'Radiohead', 'category': '欧美经典'},
  {'name': 'Coldplay', 'category': '欧美经典'},
  {'name': 'Queen', 'category': '欧美经典'},
  {'name': 'David Bowie', 'category': '欧美经典'},
  {'name': 'Nirvana', 'category': '欧美经典'},
  {'name': 'The Rolling Stones', 'category': '欧美经典'},
  {'name': 'Leonard Cohen', 'category': '欧美经典'},
  {'name': 'Bob Dylan', 'category': '欧美经典'},
  // 当代流行（10位）
  {'name': 'Adele', 'category': '当代流行'},
  {'name': 'Taylor Swift', 'category': '当代流行'},
  {'name': 'Billie Eilish', 'category': '当代流行'},
  {'name': 'The Weeknd', 'category': '当代流行'},
  {'name': 'Bruno Mars', 'category': '当代流行'},
  {'name': 'Ed Sheeran', 'category': '当代流行'},
  {'name': 'Lana Del Rey', 'category': '当代流行'},
  {'name': 'SZA', 'category': '当代流行'},
  {'name': 'Frank Ocean', 'category': '当代流行'},
  {'name': 'Kendrick Lamar', 'category': '当代流行'},
  // 爵士灵魂（5位）
  {'name': 'Miles Davis', 'category': '爵士灵魂'},
  {'name': 'John Coltrane', 'category': '爵士灵魂'},
  {'name': 'Norah Jones', 'category': '爵士灵魂'},
  {'name': 'Amy Winehouse', 'category': '爵士灵魂'},
  {'name': 'Billie Holiday', 'category': '爵士灵魂'},
  // 日本音乐（5位）
  {'name': '宇多田ヒカル', 'category': '日本音乐'},
  {'name': '坂本龍一', 'category': '日本音乐'},
  {'name': '久石譲', 'category': '日本音乐'},
  {'name': '椎名林檎', 'category': '日本音乐'},
  {'name': 'Fishmans', 'category': '日本音乐'},
  // 独立摇滚（15位）
  {'name': 'Arcade Fire', 'category': '独立摇滚'},
  {'name': 'The Strokes', 'category': '独立摇滚'},
  {'name': 'Tame Impala', 'category': '独立摇滚'},
  {'name': 'Arctic Monkeys', 'category': '独立摇滚'},
  {'name': 'Bon Iver', 'category': '独立摇滚'},
  {'name': 'Fleetwood Mac', 'category': '独立摇滚'},
  {'name': 'The National', 'category': '独立摇滚'},
  {'name': 'Sigur Rós', 'category': '独立摇滚'},
  {'name': 'Massive Attack', 'category': '独立摇滚'},
  {'name': 'Portishead', 'category': '独立摇滚'},
  {'name': 'Daft Punk', 'category': '独立摇滚'},
  {'name': 'Björk', 'category': '独立摇滚'},
  {'name': 'Brian Eno', 'category': '独立摇滚'},
  {'name': 'Tycho', 'category': '独立摇滚'},
  {'name': 'Massive Attack', 'category': '独立摇滚'},
];

// 高质量新专辑推荐关键词
final List<String> curatedAlbumKeywords = [
  // 年度热门
  '2024 年度专辑',
  '格莱美',
  '金曲奖',
  '最佳专辑',
  // 音乐风格
  '爵士精选',
  '古典名曲',
  '独立音乐',
  '民谣精选',
  '电子音乐',
  // 华语精选
  '华语经典',
  '港台金曲',
  '独立民谣',
  '摇滚精选',
  // 欧美精选
  'Billboard',
  'UK Charts',
  'Indie Rock',
  'Alternative',
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
      _loadDailyRecommendations().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.log('_loadDailyRecommendations() timed out');
          return <Song>[];
        },
      ).catchError((_) => <Song>[]),
      _loadCuratedArtists().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.log('_loadCuratedArtists() timed out');
          return <Artist>[];
        },
      ).catchError((_) => <Artist>[]),
      _loadCuratedAlbums().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.log('_loadCuratedAlbums() timed out');
          return <Album>[];
        },
      ).catchError((_) => <Album>[]),
    ]);

    final topCharts = results[0] as List<Song>;
    final recommendations = results[1] as List<Song>;
    final hotArtists = results[2] as List<Artist>;
    final newAlbums = results[3] as List<Album>;

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

  // 加载每日推荐 - 并行请求优化 (15首: 华语8, 欧美3, 日韩各2)
  Future<List<Song>> _loadDailyRecommendations() async {
    // 按配比选择艺人: 华语8, 欧美3, 日语2, 韩语2
    const chineseArtists = ['周杰伦', '林俊杰', '王力宏', '陶喆', '陈奕迅', '张学友', '王菲', '孙燕姿', 
                           '蔡依林', '林忆莲', '张惠妹', '邓紫棋', '李荣浩', '五月天', '告五人', '草东没有派对'];
    const westernArtists = ['Taylor Swift', 'Ed Sheeran', 'Adele', 'Billie Eilish', 'The Weeknd', 
                           'Bruno Mars', 'Coldplay', 'Post Malone', 'Dua Lipa', 'Ariana Grande'];
    const japaneseArtists = ['宇多田ヒカル', '椎名林檎', '坂本龍一', '久石譲', 'YOASOBI', '米津玄師'];
    const koreanArtists = ['BTS', 'BLACKPINK', 'IU', 'NewJeans', 'SEVENTEEN', 'Red Velvet'];

    final seed = _getDaySeed();
    final chineseShuffled = _shuffleList(chineseArtists.toList(), seed);
    final westernShuffled = _shuffleList(westernArtists.toList(), seed + 1);
    final japaneseShuffled = _shuffleList(japaneseArtists.toList(), seed + 2);
    final koreanShuffled = _shuffleList(koreanArtists.toList(), seed + 3);

    final selectedChinese = chineseShuffled.take(8).toList();
    final selectedWestern = westernShuffled.take(3).toList();
    final selectedJapanese = japaneseShuffled.take(2).toList();
    final selectedKorean = koreanShuffled.take(2).toList();

    final allArtists = [...selectedChinese, ...selectedWestern, ...selectedJapanese, ...selectedKorean];
    final shuffledAll = _shuffleList(allArtists, seed);
    
    // 并行发起所有请求
    final searchFutures = shuffledAll.map(
      (artist) => _apiService.searchSongs(artist).catchError((_) => <Song>[]),
    );
    final results = await Future.wait(searchFutures);
    
    // 分别收集各区域歌曲用于配比
    final chineseSongs = <Song>[];
    final westernSongs = <Song>[];
    final japaneseSongs = <Song>[];
    final koreanSongs = <Song>[];
    
    for (int i = 0; i < results.length; i++) {
      final songs = results[i];
      final artist = shuffledAll[i];
      
      if (selectedChinese.contains(artist)) {
        for (final song in songs.take(2)) {
          if (!chineseSongs.any((s) => s.id == song.id)) {
            chineseSongs.add(song);
          }
        }
      } else if (selectedWestern.contains(artist)) {
        for (final song in songs.take(2)) {
          if (!westernSongs.any((s) => s.id == song.id)) {
            westernSongs.add(song);
          }
        }
      } else if (selectedJapanese.contains(artist)) {
        for (final song in songs.take(2)) {
          if (!japaneseSongs.any((s) => s.id == song.id)) {
            japaneseSongs.add(song);
          }
        }
      } else if (selectedKorean.contains(artist)) {
        for (final song in songs.take(2)) {
          if (!koreanSongs.any((s) => s.id == song.id)) {
            koreanSongs.add(song);
          }
        }
      }
    }
    
    // 按目标配比合并结果: 华语8, 欧美3, 日语2, 韩语2
    final recommendations = <Song>[];
    final usedIds = <String>{};
    final languageCounts = <String, int>{'chinese': 0, 'western': 0, 'japanese': 0, 'korean': 0};
    
    void addSongs(List<Song> songs, String langKey, int maxCount) {
      for (final song in songs) {
        if (recommendations.length >= 15) break;
        if (!usedIds.contains(song.id) && languageCounts[langKey]! < maxCount) {
          usedIds.add(song.id);
          recommendations.add(song);
          languageCounts[langKey] = languageCounts[langKey]! + 1;
        }
      }
    }
    
    // 按配比顺序添加，确保每种语言都达到目标数量
    addSongs(chineseSongs, 'chinese', 8);
    addSongs(westernSongs, 'western', 3);
    addSongs(japaneseSongs, 'japanese', 2);
    addSongs(koreanSongs, 'korean', 2);
    
    return recommendations.take(15).toList();
  }

  // 加载精选热门歌手 - 并行请求优化
  Future<List<Artist>> _loadCuratedArtists() async {
    // 随机选择10个艺人
    final shuffledArtists = List<Map<String, String>>.from(curatedHotArtists)..shuffle();
    final selectedArtists = shuffledArtists.take(10).toList();
    
    // 第一轮：并行搜索所有艺人获取ID
    final searchFutures = selectedArtists.map(
      (artistInfo) => _apiService.searchArtists(artistInfo['name']!).catchError((_) => <Artist>[]),
    );
    final searchResults = await Future.wait(searchFutures);
    
    // 提取有ID的艺人
    final artistsWithId = <Artist>[];
    final artistIdMap = <String, String>{};
    for (int i = 0; i < searchResults.length; i++) {
      final resultsList = searchResults[i];
      if (resultsList.isNotEmpty) {
        final artist = resultsList.first;
        if (artist.id.isNotEmpty) {
          artistsWithId.add(artist);
          artistIdMap[artist.name] = artist.id;
        }
      }
    }
    
    // 第二轮：获取艺人详情（包括musicNum）
    final artistsWithDetail = <Artist>[];
    final detailFutures = artistsWithId.map(
      (artist) => _apiService.getArtistDetailWithSongs(artist.id).catchError((_) => (null, <Song>[])),
    );
    final detailResults = await Future.wait(detailFutures);
    
    for (int i = 0; i < detailResults.length; i++) {
      final (detailArtist, _) = detailResults[i];
      if (detailArtist != null) {
        artistsWithDetail.add(detailArtist);
      } else {
        artistsWithDetail.add(artistsWithId[i]);
      }
    }
    
    return artistsWithDetail.take(10).toList();
  }

  // 加载精选新专辑 - 并行请求优化
  Future<List<Album>> _loadCuratedAlbums() async {
    final shuffledKeywords = List<String>.from(curatedAlbumKeywords)..shuffle();
    final selectedKeywords = shuffledKeywords.take(3).toList();
    
    // 并行搜索
    final searchFutures = selectedKeywords.map(
      (keyword) => _apiService.searchAlbums(keyword).catchError((_) => <Album>[]),
    );
    final results = await Future.wait(searchFutures);
    
    // 合并去重
    final albums = <Album>[];
    final seenIds = <String>{};
    for (final albumList in results) {
      for (final album in albumList) {
        if (!seenIds.contains(album.id)) {
          seenIds.add(album.id);
          albums.add(album);
        }
      }
    }
    
    return albums.take(10).toList();
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

  List<Song> _enforceArtistDiversity(List<Song> songs, {int maxPerArtist = 2}) {
    final artistCount = <String, int>{};
    final result = <Song>[];
    for (final song in songs) {
      final artist = song.artist.toLowerCase();
      final count = artistCount.putIfAbsent(artist, () => 0);
      if (count < maxPerArtist) {
        result.add(song);
        artistCount[artist] = count + 1;
      }
    }
    return result;
  }

  static const List<String> _fallbackArtists = [
    '周杰伦', 'Taylor Swift', '林俊杰', '陈奕迅', 'Adele',
    '王菲', 'Ed Sheeran', 'Coldplay', '孙燕姿', '李荣浩',
    'Ariana Grande', '陶喆', '王力宏', '蔡依林', '张学友',
    'Billie Eilish', 'Drake', 'G.E.M.', '梁静茹', 'Justin Bieber',
  ];

  static const List<String> _fallbackAlbums = [
    '最伟大的作品', '范特西', 'Midnights', 'Folklore', '十年',
    '寓言', '她说', 'Dawn FM', 'Back to Black', 'UGLY BEAUTY',
    'Happier Than Ever', '光年之外', '幸存者', '等于', '第二人生',
    'When We All Fall Asleep', '和自己对话', '坏喔', '好想好想', '我很忙',
  ];

  Future<List<Song>> _buildDiverseFallback() async {
    final seed = _getDaySeed();
    final shuffledArtists = _shuffleList(_fallbackArtists, seed);
    final selectedArtists = shuffledArtists.take(10).toList();

    final allSongs = <Song>[];
    for (final artist in selectedArtists) {
      try {
        final songs = await _apiService.searchSongs(artist);
        allSongs.addAll(songs.take(2));
      } catch (_) {}
    }

    return _enforceArtistDiversity(allSongs, maxPerArtist: 2).take(10).toList();
  }

  Future<List<Artist>> _buildDiverseArtistsFallback() async {
    final seed = _getDaySeed();
    final shuffled = _shuffleList(_fallbackArtists, seed);
    final artists = <Artist>[];
    final seenIds = <String>{};

    for (final name in shuffled) {
      if (artists.length >= 10) break;
      try {
        final results = await _apiService.searchArtists(name);
        if (results.isNotEmpty) {
          final artist = results.first;
          if (!seenIds.contains(artist.id)) {
            artists.add(artist);
            seenIds.add(artist.id);
          }
        }
      } catch (_) {}
    }

    return artists.take(10).toList();
  }

  Future<List<Album>> _buildDiverseAlbumsFallback() async {
    final seed = _getDaySeed();
    final shuffled = _shuffleList(_fallbackAlbums, seed);
    final albums = <Album>[];
    final seenIds = <String>{};

    for (final albumName in shuffled) {
      if (albums.length >= 10) break;
      try {
        final results = await _apiService.searchAlbums(albumName);
        if (results.isNotEmpty) {
          final album = results.first;
          if (!seenIds.contains(album.id)) {
            albums.add(album);
            seenIds.add(album.id);
          }
        }
      } catch (_) {}
    }

    return albums.take(10).toList();
  }

  int _getDaySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  List<T> _shuffleList<T>(List<T> list, int seed) {
    final result = List<T>.from(list);
    for (var i = result.length - 1; i > 0; i--) {
      final j = (seed * (i + 1) * 31) % (i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }
}
