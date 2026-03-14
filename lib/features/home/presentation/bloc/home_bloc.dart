import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/music_api_service.dart' show AppLogger;

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

  const HomeState({
    this.isLoading = false,
    this.error,
    this.recentPlays = const [],
    this.topCharts = const [],
    this.recommendations = const [],
  });

  HomeState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? recentPlays,
    List<Song>? topCharts,
    List<Song>? recommendations,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recentPlays: recentPlays ?? this.recentPlays,
      topCharts: topCharts ?? this.topCharts,
      recommendations: recommendations ?? this.recommendations,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, recentPlays, topCharts, recommendations];
}

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final MusicApiService _apiService = MusicApiService.instance;

  HomeBloc() : super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<AddToRecentPlays>(_onAddToRecentPlays);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      final recentSongs = recentBox.values.map((e) {
        if (e is Map) {
          return Song.fromJson(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>().toList();
      
      final topCharts = await _apiService.getTopCharts();
      final recommendations = await _apiService.searchSongs('pop');

      emit(state.copyWith(
        isLoading: false,
        recentPlays: recentSongs,
        topCharts: topCharts,
        recommendations: recommendations,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '加载数据失败: $e',
      ));
    }
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
          return Song.fromJson(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>().toList();
      emit(state.copyWith(recentPlays: recentSongs));
    } catch (e) {
      AppLogger.log('Error adding to recent: $e');
    }
  }
}
