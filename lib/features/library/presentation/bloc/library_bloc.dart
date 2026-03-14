import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

part 'library_event.dart';

class Playlist extends Equatable {
  final String name;
  final List<Song> songs;
  final String? coverUrl;

  const Playlist({
    required this.name,
    this.songs = const [],
    this.coverUrl,
  });

  @override
  List<Object?> get props => [name, songs, coverUrl];
}

class LibraryState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Song> localSongs;
  final List<String> artists;
  final List<String> albums;
  final List<Playlist> playlists;

  const LibraryState({
    this.isLoading = false,
    this.error,
    this.localSongs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  LibraryState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? localSongs,
    List<String>? artists,
    List<String>? albums,
    List<Playlist>? playlists,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      localSongs: localSongs ?? this.localSongs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, localSongs, artists, albums, playlists];
}

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc() : super(const LibraryState()) {
    on<LoadLocalMusic>(_onLoadLocalMusic);
    on<RequestPermission>(_onRequestPermission);
    on<LoadPlaylists>(_onLoadPlaylists);
  }

  Future<void> _onLoadLocalMusic(LoadLocalMusic event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: false, error: '本地音乐功能待实现，请使用在线搜索'));
  }

  Future<void> _onRequestPermission(RequestPermission event, Emitter<LibraryState> emit) async {
    add(LoadLocalMusic());
  }

  Future<void> _onLoadPlaylists(LoadPlaylists event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(
      playlists: [
        const Playlist(name: '我喜欢的音乐', songs: []),
        const Playlist(name: '最近播放', songs: []),
      ],
    ));
  }
}
