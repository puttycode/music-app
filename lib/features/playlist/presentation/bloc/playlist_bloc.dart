import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/features/playlist/domain/entities/playlist.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

part 'playlist_event.dart';

class PlaylistState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Playlist> playlists;

  const PlaylistState({
    this.isLoading = false,
    this.error,
    this.playlists = const [],
  });

  PlaylistState copyWith({
    bool? isLoading,
    String? error,
    List<Playlist>? playlists,
  }) {
    return PlaylistState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      playlists: playlists ?? this.playlists,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, playlists];
}

class PlaylistBloc extends Bloc<PlaylistEvent, PlaylistState> {
  final Box _playlistBox = Hive.box(AppConstants.playlistBox);

  PlaylistBloc() : super(const PlaylistState()) {
    on<LoadPlaylists>(_onLoadPlaylists);
    on<CreatePlaylist>(_onCreatePlaylist);
    on<DeletePlaylist>(_onDeletePlaylist);
    on<AddSongToPlaylist>(_onAddSongToPlaylist);
    on<RemoveSongFromPlaylist>(_onRemoveSongFromPlaylist);
  }

  void _onLoadPlaylists(LoadPlaylists event, Emitter<PlaylistState> emit) {
    emit(state.copyWith(isLoading: true));

    try {
      final playlists = _playlistBox.values
          .map((json) => Playlist.fromJson(Map<String, dynamic>.from(json)))
          .toList();
      
      emit(state.copyWith(isLoading: false, playlists: playlists));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '加载播放列表失败: $e'));
    }
  }

  Future<void> _onCreatePlaylist(CreatePlaylist event, Emitter<PlaylistState> emit) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: event.name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _playlistBox.put(playlist.id, playlist.toJson());
    add(LoadPlaylists());
  }

  Future<void> _onDeletePlaylist(DeletePlaylist event, Emitter<PlaylistState> emit) async {
    await _playlistBox.delete(event.id);
    add(LoadPlaylists());
  }

  Future<void> _onAddSongToPlaylist(AddSongToPlaylist event, Emitter<PlaylistState> emit) async {
    final playlist = state.playlists.firstWhere((p) => p.id == event.playlistId);
    final updatedSongs = [...playlist.songs, event.song];
    final updatedPlaylist = playlist.copyWith(
      songs: updatedSongs,
      updatedAt: DateTime.now(),
    );

    await _playlistBox.put(playlist.id, updatedPlaylist.toJson());
    add(LoadPlaylists());
  }

  Future<void> _onRemoveSongFromPlaylist(RemoveSongFromPlaylist event, Emitter<PlaylistState> emit) async {
    final playlist = state.playlists.firstWhere((p) => p.id == event.playlistId);
    final updatedSongs = playlist.songs.where((s) => s.id != event.songId).toList();
    final updatedPlaylist = playlist.copyWith(
      songs: updatedSongs,
      updatedAt: DateTime.now(),
    );

    await _playlistBox.put(playlist.id, updatedPlaylist.toJson());
    add(LoadPlaylists());
  }
}
