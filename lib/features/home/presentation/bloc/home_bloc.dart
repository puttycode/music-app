import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/services/music_api_service.dart';
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

    // Load recommendations
    try {
      recommendations = await _apiService.searchSongs('周杰伦');
      if (recommendations.isEmpty) {
        recommendations = await _apiService.searchSongs('Taylor Swift');
      }
      recommendations = recommendations.take(10).toList();
      AppLogger.log('Loaded ${recommendations.length} recommendations');
    } catch (e) {
      AppLogger.log('Load recommendations failed: $e');
    }

    // Load hot artists using the dedicated API
    try {
      hotArtists = await _apiService.getHotArtists();
      if (hotArtists.isEmpty) {
        // Fallback to search
        hotArtists = await _apiService.searchArtists('周杰伦');
      }
      hotArtists = hotArtists.take(10).toList();
      AppLogger.log('Loaded ${hotArtists.length} hot artists');
    } catch (e) {
      AppLogger.log('Load hot artists failed: $e');
    }

    // Load new albums using the dedicated API
    try {
      newAlbums = await _apiService.getNewAlbums();
      if (newAlbums.isEmpty) {
        // Fallback to search
        newAlbums = await _apiService.searchAlbums('周杰伦');
      }
      newAlbums = newAlbums.take(10).toList();
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
}
