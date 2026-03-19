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

  const HomeState({
    this.isLoading = false,
    this.error,
    this.recentPlays = const [],
    this.topCharts = const [],
    this.recommendations = const [],
    this.hotArtists = const [],
    this.newAlbums = const [],
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? recentPlays,
    List<Song>? topCharts,
    List<Song>? recommendations,
    List<Artist>? hotArtists,
    List<Album>? newAlbums,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recentPlays: recentPlays ?? this.recentPlays,
      topCharts: topCharts ?? this.topCharts,
      recommendations: recommendations ?? this.recommendations,
      hotArtists: hotArtists ?? this.hotArtists,
      newAlbums: newAlbums ?? this.newAlbums,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, recentPlays, topCharts, recommendations, hotArtists, newAlbums];
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

    // Load data with better error handling
    List<Song> topCharts = [];
    List<Song> recommendations = [];
    List<Artist> hotArtists = [];
    List<Album> newAlbums = [];

    // Load top charts
    try {
      topCharts = await _apiService.getTopCharts();
      AppLogger.log('Loaded ${topCharts.length} top charts');
    } catch (e) {
      AppLogger.log('Load top charts failed: $e');
    }

    // Load recommendations with curated quality + daily rotation + artist diversity
    try {
      recommendations = await CuratedRecommendations.getDailyRecommendations(targetCount: 10);
      if (recommendations.isEmpty) {
        recommendations = await _buildDiverseFallback();
      }
      AppLogger.log('Loaded ${recommendations.length} recommendations');
    } catch (e) {
      AppLogger.log('Load recommendations failed: $e');
    }

    // Load hot artists using curated daily rotation
    try {
      hotArtists = await CuratedRecommendations.getDailyHotArtists();
      if (hotArtists.isEmpty) {
        hotArtists = await _buildDiverseArtistsFallback();
      }
      AppLogger.log('Loaded ${hotArtists.length} hot artists');
    } catch (e) {
      AppLogger.log('Load hot artists failed: $e');
    }

    // Load new albums using curated daily rotation
    try {
      newAlbums = await CuratedRecommendations.getDailyNewAlbums();
      if (newAlbums.isEmpty) {
        newAlbums = await _buildDiverseAlbumsFallback();
      }
      AppLogger.log('Loaded ${newAlbums.length} new albums');
    } catch (e) {
      AppLogger.log('Load new albums failed: $e');
    }

    final hasAnyData = recentSongs.isNotEmpty || 
                       topCharts.isNotEmpty || 
                       recommendations.isNotEmpty ||
                       hotArtists.isNotEmpty ||
                       newAlbums.isNotEmpty;

    emit(state.copyWith(
      isLoading: false,
      error: hasAnyData ? null : '暂无数据',
      recentPlays: recentSongs,
      topCharts: topCharts,
      recommendations: recommendations,
      hotArtists: hotArtists,
      newAlbums: newAlbums,
    ));
  }

  Future<void> _onAddToRecentPlays(AddToRecentPlays event, Emitter<HomeState> emit) async {
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      
      // Remove existing song with same ID
      final existingKeys = recentBox.keys.where((key) {
        final item = recentBox.get(key);
        if (item is Map) {
          return item['id'] == event.song.id;
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
