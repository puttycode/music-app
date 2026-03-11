import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/services/music_api_service.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class SearchSongs extends SearchEvent {
  final String query;

  const SearchSongs(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearch extends SearchEvent {}

class SearchState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Song> results;
  final String query;

  const SearchState({
    this.isLoading = false,
    this.error,
    this.results = const [],
    this.query = '',
  });

  SearchState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? results,
    String? query,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      results: results ?? this.results,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, results, query];
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final MusicApiService _apiService = MusicApiService.instance;

  SearchBloc() : super(const SearchState()) {
    on<SearchSongs>(_onSearchSongs);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchSongs(SearchSongs event, Emitter<SearchState> emit) async {
    emit(state.copyWith(isLoading: true, query: event.query));

    try {
      final results = await _apiService.searchSongs(event.query);
      emit(state.copyWith(isLoading: false, results: results));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '搜索失败: $e'));
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
