import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:rxdart/rxdart.dart';

class FavoriteService {
  FavoriteService._();
  static final FavoriteService _instance = FavoriteService._();
  static FavoriteService get instance => _instance;

  final _favoritesChangedSubject = BehaviorSubject<void>.seeded(null);
  Stream<void> get favoritesChanged => _favoritesChangedSubject.asBroadcastStream();

  // Callback to refresh library playlists
  VoidCallback? onFavoriteChanged;

  Future<void> toggleFavorite(Song song) async {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);
      const favoritePlaylistName = '我喜欢的音乐';

      // Check if favorite playlist exists in Hive
      var favoritePlaylistData = playlistBox.get(favoritePlaylistName);
      List<Song> favoriteSongs = [];

      if (favoritePlaylistData is Map && favoritePlaylistData['songs'] is List) {
        final songsData = favoritePlaylistData['songs'] as List;
        favoriteSongs = songsData
            .map((songData) => Song.fromLocal(Map<String, dynamic>.from(songData)))
            .whereType<Song>()
            .toList();
      }

      final isFavorite = favoriteSongs.any((favSong) => favSong.id == song.id);

      if (isFavorite) {
        favoriteSongs.removeWhere((favSong) => favSong.id == song.id);
      } else {
        favoriteSongs.add(song);
      }

      // Update or create the favorite playlist
      await playlistBox.put(favoritePlaylistName, {
        'name': favoritePlaylistName,
        'songs': favoriteSongs.map((s) => s.toJson()).toList(),
        'icon': 'favorite',
      });

      _favoritesChangedSubject.add(null);
      
      // Trigger callback to refresh library playlists
      onFavoriteChanged?.call();
    } catch (e) {
      // Ignore errors
    }
  }

  bool isFavorite(Song song) {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);
      const favoritePlaylistName = '我喜欢的音乐';
      final favoritePlaylistData = playlistBox.get(favoritePlaylistName);

      if (favoritePlaylistData is Map && favoritePlaylistData['songs'] is List) {
        final songsData = favoritePlaylistData['songs'] as List;
        final favoriteSongs = songsData
            .map((songData) => Song.fromLocal(Map<String, dynamic>.from(songData)))
            .whereType<Song>()
            .toList();

        return favoriteSongs.any((favSong) => favSong.id == song.id);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _favoritesChangedSubject.close();
  }
}
