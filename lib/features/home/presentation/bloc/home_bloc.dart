import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/constants/api_constants.dart';
import 'package:music_app/core/dio_client.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

part 'home_event.dart';

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
  HomeBloc() : super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final dio = DioClient.instance;
      
      final chartsResponse = await dio.get(ApiConstants.deezerChart);
      final topCharts = (chartsResponse.data['data'] as List)
          .map((json) => Song.fromJson(json))
          .toList();

      final searchResponse = await dio.get('${ApiConstants.deezerSearch}', queryParameters: {'q': 'pop'});
      final recommendations = (searchResponse.data['data'] as List)
          .map((json) => Song.fromJson(json))
          .toList();

      emit(state.copyWith(
        isLoading: false,
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
}
