part of 'search_bloc.dart';

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
