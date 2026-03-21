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
import 'package:music_app/services/download_service.dart';

part 'library_event.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final List<Song> songs;
  final String? coverUrl;
  final String icon;

  const Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
    this.coverUrl,
    this.icon = 'queue_music',
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<Song>? songs,
    String? coverUrl,
    String? icon,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      coverUrl: coverUrl ?? this.coverUrl,
      icon: icon ?? this.icon,
    );
  }

  @override
  List<Object?> get props => [id, name, songs, coverUrl, icon];
}

class LibraryState extends Equatable {
  final bool isLoading;
  final String? error;
  final List<Song> localSongs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;
  final bool playlistCreated;

  const LibraryState({
    this.isLoading = false,
    this.error,
    this.localSongs = const [],
    this.artists = const <Artist>[],
    this.albums = const <Album>[],
    this.playlists = const [],
    this.playlistCreated = false,
  });

  LibraryState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<Song>? localSongs,
    List<Artist>? artists,
    List<Album>? albums,
    List<Playlist>? playlists,
    bool? playlistCreated,
  }) {
    return LibraryState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      localSongs: localSongs ?? this.localSongs,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      playlists: playlists ?? this.playlists,
      playlistCreated: playlistCreated ?? false,
    );
  }

  @override
  List<Object?> get props => [isLoading, error, localSongs, artists, albums, playlists, playlistCreated];
}

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc() : super(const LibraryState()) {
    on<LoadLocalMusic>(_onLoadLocalMusic);
    on<RequestPermission>(_onRequestPermission);
    on<LoadPlaylists>(_onLoadPlaylists);
    on<RefreshPlaylists>(_onRefreshPlaylists);
    on<CreatePlaylist>(_onCreatePlaylist);
    on<DeletePlaylist>(_onDeletePlaylist);
    on<RenamePlaylist>(_onRenamePlaylist);
    on<ClearPlaylistCreatedFlag>(_onClearPlaylistCreatedFlag);
  }

  Future<void> _onLoadLocalMusic(LoadLocalMusic event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      // Scan device for local music files
      final scannedSongs = await LocalMusicScanner.scan();
      
      // Get downloaded songs
      final downloadedSongs = DownloadService.instance.getDownloadedSongs();
      
      // Combine and deduplicate (prefer downloaded versions with correct metadata)
      final songsMap = <String, Song>{};
      for (final song in scannedSongs) {
        songsMap[song.id] = song;
      }
      for (final song in downloadedSongs) {
        songsMap[song.id] = song;
      }
      final localSongs = songsMap.values.toList();
      
      // Also load recent plays for artist/album extraction
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      final recentSongs = recentBox.values.map((e) {
        if (e is Map) {
          return Song.fromLocal(Map<String, dynamic>.from(e));
        }
        return null;
      }).whereType<Song>().toList();
      
      // Combine local songs and recent songs for artist/album extraction
      final allSongs = [...localSongs, ...recentSongs];
      
      // Create artist map with song count and avatar
      final artistMap = <String, Map<String, dynamic>>{};
      for (final song in allSongs) {
        if (song.artist.isNotEmpty) {
          if (!artistMap.containsKey(song.artist)) {
            artistMap[song.artist] = {
              'count': 0,
              'avatar': song.albumArt, // Use album art as avatar
            };
          }
          artistMap[song.artist]!['count'] = (artistMap[song.artist]!['count'] as int) + 1;
        }
      }
      
      // Create album map with cover
      final albumMap = <String, Map<String, dynamic>>{};
      for (final song in allSongs) {
        if (song.album.isNotEmpty) {
          if (!albumMap.containsKey(song.album)) {
            albumMap[song.album] = {
              'count': 0,
              'cover': song.albumArt,
              'artist': song.artist,
            };
          }
          albumMap[song.album]!['count'] = (albumMap[song.album]!['count'] as int) + 1;
        }
      }
      
      // Create Artist objects
      final artists = artistMap.entries.map((entry) => Artist(
        id: entry.key,
        name: entry.key,
        avatar: entry.value['avatar'] as String?,
        musicNum: entry.value['count'] as int,
      )).toList();
      
      // Create Album objects
      final albums = albumMap.entries.map((entry) => Album(
        id: entry.key,
        name: entry.key,
        artist: entry.value['artist'] as String?,
        cover: entry.value['cover'] as String?,
      )).toList();
      
      emit(state.copyWith(
        isLoading: false,
        clearError: true,
        localSongs: localSongs,
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
    await _refreshPlaylistsData(emit);
  }

  Future<void> _onRefreshPlaylists(RefreshPlaylists event, Emitter<LibraryState> emit) async {
    await _refreshPlaylistsData(emit);
  }

  Future<void> _refreshPlaylistsData(Emitter<LibraryState> emit) async {
    // Load recent plays from Hive for "最近播放"
    final recentBox = Hive.box(AppConstants.recentPlaysBox);
    final recentSongs = recentBox.values.map((e) {
      if (e is Map) {
        return Song.fromLocal(Map<String, dynamic>.from(e));
      }
      return null;
    }).whereType<Song>().toList();
    
    // Sort recent plays by playedAt timestamp (newest first)
    recentSongs.sort((a, b) {
      if (a.playedAt == null && b.playedAt == null) return 0;
      if (a.playedAt == null) return 1;
      if (b.playedAt == null) return -1;
      return b.playedAt!.compareTo(a.playedAt!);
    });
    
    // Load user playlists from Hive
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final userPlaylists = <Playlist>[];

    for (final key in playlistBox.keys) {
      final value = playlistBox.get(key);
      if (value is! Map) continue;

      final data = Map<String, dynamic>.from(value);
      final songs = (data['songs'] as List?)?.map((s) {
        if (s is Map) {
          return Song.fromLocal(Map<String, dynamic>.from(s));
        }
        return null;
      }).whereType<Song>().toList() ?? <Song>[];

      final id = (data['id'] ?? key).toString();
      final name = (data['name'] ?? key).toString();

      userPlaylists.add(
        Playlist(
          id: id,
          name: name,
          songs: songs,
          coverUrl: data['coverImage'] ?? data['coverUrl'],
          icon: (data['icon'] ?? 'queue_music').toString(),
        ),
      );
    }
    
    // Find "我喜欢的音乐" from Hive or create empty one
    final favoritePlaylist = userPlaylists.firstWhere(
      (p) => p.name == '我喜欢的音乐',
      orElse: () => const Playlist(id: 'favorites', name: '我喜欢的音乐', songs: [], icon: 'favorite'),
    );
    
    // Remove from userPlaylists to avoid duplicates
    final otherPlaylists = userPlaylists.where((p) => p.name != '我喜欢的音乐' && p.name != '最近播放').toList();
    
    emit(state.copyWith(
      clearError: true,
      playlists: [
        favoritePlaylist,
        Playlist(
          id: 'recent',
          name: '最近播放',
          songs: recentSongs,
          icon: 'history',
        ),
        ...otherPlaylists,
      ],
    ));
  }

  Future<void> _onCreatePlaylist(CreatePlaylist event, Emitter<LibraryState> emit) async {
    final trimmedName = event.name.trim();
    if (trimmedName.isEmpty) {
      emit(state.copyWith(error: '播放列表名称不能为空'));
      return;
    }
    
    final normalizedName = trimmedName.toLowerCase();
    final existingPlaylist = state.playlists.firstWhere(
      (p) => p.name.trim().toLowerCase() == normalizedName,
      orElse: () => Playlist(id: '', name: '', songs: []),
    );
    
    if (existingPlaylist.id.isNotEmpty) {
      emit(state.copyWith(error: '播放列表名称已存在'));
      return;
    }
    
    final playlistId = DateTime.now().millisecondsSinceEpoch.toString();
    final newPlaylist = Playlist(
      id: playlistId,
      name: trimmedName,
      songs: const [],
    );
    
    final playlistBox = Hive.box(AppConstants.playlistBox);
    await playlistBox.put(playlistId, {
      'id': playlistId,
      'name': trimmedName,
      'songs': <Map>[],
    });
    
    emit(state.copyWith(
      clearError: true,
      playlistCreated: true,
      playlists: [...state.playlists, newPlaylist],
    ));
  }

  Future<void> _onDeletePlaylist(DeletePlaylist event, Emitter<LibraryState> emit) async {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    await playlistBox.delete(event.playlistId);

    if (event.legacyName != null && event.legacyName != event.playlistId) {
      await playlistBox.delete(event.legacyName);
    }
    
    final updatedPlaylists = state.playlists.where((p) => p.id != event.playlistId).toList();
    emit(state.copyWith(playlists: updatedPlaylists));
  }

  Future<void> _onRenamePlaylist(RenamePlaylist event, Emitter<LibraryState> emit) async {
    final trimmedNewName = event.newName.trim();
    if (trimmedNewName.isEmpty) {
      emit(state.copyWith(error: '播放列表名称不能为空'));
      return;
    }
    
    final normalizedName = trimmedNewName.toLowerCase();
    final existingPlaylist = state.playlists.firstWhere(
      (p) => p.id != event.playlistId && p.name.trim().toLowerCase() == normalizedName,
      orElse: () => Playlist(id: '', name: '', songs: []),
    );
    
    if (existingPlaylist.id.isNotEmpty) {
      emit(state.copyWith(error: '播放列表名称已存在'));
      return;
    }
    
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final playlistData = playlistBox.get(event.playlistId);
    
    if (playlistData is Map) {
      playlistData['name'] = trimmedNewName;
      await playlistBox.put(event.playlistId, playlistData);
    }
    
    final updatedPlaylists = state.playlists.map((p) {
      if (p.id == event.playlistId) {
        return p.copyWith(name: trimmedNewName);
      }
      return p;
    }).toList();
    
    emit(state.copyWith(playlists: updatedPlaylists));
  }

  void _onClearPlaylistCreatedFlag(ClearPlaylistCreatedFlag event, Emitter<LibraryState> emit) {
    emit(state.copyWith(playlistCreated: false));
  }
}
