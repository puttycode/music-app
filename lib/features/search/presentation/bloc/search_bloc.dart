import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/dio_client.dart';
import '../../domain/entities/song.dart';

part 'search_event.dart';

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
  SearchBloc() : super(const SearchState()) {
    on<SearchSongs>(_onSearchSongs);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchSongs(SearchSongs event, Emitter<SearchState> emit) async {
    emit(state.copyWith(isLoading: true, query: event.query));

    try {
      final dio = DioClient.instance;
      final response = await dio.get(
        ApiConstants.deezerSearch,
        queryParameters: {'q': event.query},
      );

      final results = (response.data['data'] as List)
          .map((json) => Song.fromJson(json))
          .toList();

      emit(state.copyWith(isLoading: false, results: results));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '搜索失败: $e'));
    }
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
