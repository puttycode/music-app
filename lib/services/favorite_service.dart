import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:rxdart/rxdart.dart';

class FavoriteService {
  FavoriteService._();
  static final FavoriteService _instance = FavoriteService._();
  static FavoriteService get instance => _instance;

  final _favoritesChangedSubject = BehaviorSubject<void>();
  Stream<void> get favoritesChanged => _favoritesChangedSubject.asBroadcastStream();

  Future<void> toggleFavorite(Song song) async {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);
      final favoritePlaylistName = '我喜欢的音乐';

      // Get the existing favorite playlist or create a new one if it doesn't exist
      final favoritePlaylistData = playlistBox.get(favoritePlaylistName);
      List<Song> favoriteSongs = [];

      if (favoritePlaylistData is Map && favoritePlaylistData['songs'] is List) {
        final songsData = favoritePlaylistData['songs'] as List;
        favoriteSongs = songsData
            .map((songData) => Song.fromLocal(Map<String, dynamic>.from(songData)))
            .whereType<Song>()
            .toList();
      }

      // Check if the song is already in favorites
      final isFavorite = favoriteSongs.any((favSong) => favSong.id == song.id);

      if (isFavorite) {
        // Remove from favorites
        favoriteSongs.removeWhere((favSong) => favSong.id == song.id);
      } else {
        // Add to favorites
        favoriteSongs.add(song);
      }

      // Save the updated favorite playlist back to Hive
      await playlistBox.put(favoritePlaylistName, {
        'name': favoritePlaylistName,
        'songs': favoriteSongs.map((song) => song.toJson()).toList(),
        'icon': 'favorite',
      });

      // Notify listeners that favorites have changed
      _favoritesChangedSubject.add(null);
    } catch (e) {
      // Ignore errors for now
    }
  }

  Future<bool> isFavorite(Song song) async {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);
      final favoritePlaylistName = '我喜欢的音乐';
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