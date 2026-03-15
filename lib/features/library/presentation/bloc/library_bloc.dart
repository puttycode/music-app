import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/audio_player_service.dart' show AppLogger, AudioPlayerService;
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/services/local_music_scanner.dart';

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
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  const LibraryState({
    this.isLoading = false,
    this.error,
    this.localSongs = const [],
    this.artists = const <Artist>[],
    this.albums = const <Album>[],
    this.playlists = const [],
  });

  LibraryState copyWith({
    bool? isLoading,
    String? error,
    List<Song>? localSongs,
    List<Artist>? artists,
    List<Album>? albums,
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
    on<CreatePlaylist>(_onCreatePlaylist);
    on<DeletePlaylist>(_onDeletePlaylist);
  }

  Future<void> _onLoadLocalMusic(LoadLocalMusic event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      // Scan for local music files on device
      final localSongs = await LocalMusicScanner.scan();
      
      // Load recent plays from Hive for artist/album extraction
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      final recentSongs = recentBox.values.map((e) {
        if (e is Map) {
          return Song.fromLocal(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>().toList();
      
      // Extract unique artist and album names from recent plays
      final artistNames = recentSongs.map((s) => s.artist).toSet().toList();
      final albumNames = recentSongs.map((s) => s.album).toSet().toList();
      
      // Create Artist and Album objects from names
      final artists = artistNames.map((name) => Artist(
        id: name,
        name: name,
      )).toList();
      
      final albums = albumNames.map((name) => Album(
        id: name,
        name: name,
      )).toList();
      
      emit(state.copyWith(
        isLoading: false,
        localSongs: localSongs,
        artists: artists,
        albums: albums,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '加载失败: $e'));
    }
  }

  Future<void> _onRequestPermission(RequestPermission event, Emitter<LibraryState> emit) async {
    add(LoadLocalMusic());
  }

  Future<void> _onLoadPlaylists(LoadPlaylists event, Emitter<LibraryState> emit) async {
    // Load recent plays from Hive for "最近播放"
    final recentBox = Hive.box(AppConstants.recentPlaysBox);
    final recentSongs = recentBox.values.map((e) {
      if (e is Map) {
        return Song.fromLocal(Map<String, dynamic>.from(e));
      }
      return null;
    }).whereType<Song>().toList();
    
    // Load user playlists from Hive
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final userPlaylists = playlistBox.values.map((e) {
      if (e is Map) {
        final songs = (e['songs'] as List?)?.map((s) {
          if (s is Map) {
            return Song.fromLocal(Map<String, dynamic>.from(s));
          }
          return null;
        }).whereType<Song>().toList() ?? <Song>[];
        
        return Playlist(
          name: e['name'] ?? '未知',
          songs: songs,
          icon: e['icon'] ?? 'queue_music',
        );
      }
      return null;
    }).whereType<Playlist>().toList();
    
    emit(state.copyWith(
      playlists: [
        Playlist(
          name: '我喜欢的音乐',
          songs: const [],
          icon: 'favorite',
        ),
        Playlist(
          name: '最近播放',
          songs: recentSongs,
          icon: 'history',
        ),
        ...userPlaylists,
      ],
    ));
  }

  Future<void> _onCreatePlaylist(CreatePlaylist event, Emitter<LibraryState> emit) async {
    final newPlaylist = Playlist(name: event.name, songs: const [], icon: 'queue_music');
    
    // Save to Hive
    final playlistBox = Hive.box(AppConstants.playlistBox);
    await playlistBox.put(event.name, {
      'name': event.name,
      'songs': <Map>[],
      'icon': 'queue_music',
    });
    
    emit(state.copyWith(
      playlists: [...state.playlists, newPlaylist],
    ));
  }

  Future<void> _onDeletePlaylist(DeletePlaylist event, Emitter<LibraryState> emit) async {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    await playlistBox.delete(event.name);
    
    final updatedPlaylists = state.playlists.where((p) => p.name != event.name).toList();
    emit(state.copyWith(playlists: updatedPlaylists));
  }
}
