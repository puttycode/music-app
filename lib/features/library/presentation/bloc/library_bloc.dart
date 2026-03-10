import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

part 'library_event.dart';

class LibraryState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Song> localSongs;
  final List<String> artists;
  final List<String> albums;

  const LibraryState({
    this.isLoading = false,
    this.error,
    this.localSongs = const [],
    this.artists = const [],
    this.albums = const [],
  });

  LibraryState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? localSongs,
    List<String>? artists,
    List<String>? albums,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      localSongs: localSongs ?? this.localSongs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, localSongs, artists, albums];
}

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  LibraryBloc() : super(const LibraryState()) {
    on<LoadLocalMusic>(_onLoadLocalMusic);
    on<RequestPermission>(_onRequestPermission);
  }

  Future<void> _onLoadLocalMusic(LoadLocalMusic event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true));

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      final songList = songs.map((s) => Song(
        id: s.id,
        title: s.title,
        artist: s.artist ?? 'Unknown Artist',
        album: s.album ?? 'Unknown Album',
        duration: Duration(milliseconds: s.duration ?? 0),
        isLocal: true,
        localPath: s.data,
        albumArt: null,
        audioUrl: null,
      )).toList();

      final artists = songs
          .map((s) => s.artist ?? 'Unknown Artist')
          .toSet()
          .toList();

      final albums = songs
          .map((s) => s.album ?? 'Unknown Album')
          .toSet()
          .toList();

      emit(state.copyWith(
        isLoading: false,
        localSongs: songList,
        artists: artists,
        albums: albums,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '加载本地音乐失败: $e',
      ));
    }
  }

  Future<void> _onRequestPermission(RequestPermission event, Emitter<LibraryState> emit) async {
    add(LoadLocalMusic());
  }
}
