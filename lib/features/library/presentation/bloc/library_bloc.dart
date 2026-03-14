import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/audio_player_service.dart';

part 'library_event.dart';

class Playlist extends Equatable {
  final String name;
  final List<Song> songs;
  final String? coverUrl;
  final String icon;

  const Playlist({
    required this.name,
    this.songs = const [],
    this.coverUrl,
    this.icon = 'queue_music',
  });

  @override
  List<Object?> get props => [name, songs, coverUrl, icon];
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
    emit(state.copyWith(isLoading: true));
    
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      final recentSongs = recentBox.values.map((e) => e as Song).toList();
      
      final artists = recentSongs.map((s) => s.artist).toSet().toList();
      final albums = recentSongs.map((s) => s.album).toSet().toList();
      
      emit(state.copyWith(
        isLoading: false,
        localSongs: recentSongs,
        artists: artists,
        albums: albums,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '加载失败'));
    }
  }

  Future<void> _onRequestPermission(RequestPermission event, Emitter<LibraryState> emit) async {
    add(LoadLocalMusic());
  }

  Future<void> _onLoadPlaylists(LoadPlaylists event, Emitter<LibraryState> emit) async {
    final audioService = AudioPlayerService.instance;
    final currentPlaylist = audioService.playlist;
    
    emit(state.copyWith(
      playlists: [
        Playlist(
          name: '我喜欢的音乐',
          songs: const [],
          icon: 'favorite',
        ),
        Playlist(
          name: '最近播放',
          songs: currentPlaylist.isNotEmpty ? currentPlaylist : const [],
          icon: 'history',
        ),
      ],
    ));
  }
}
