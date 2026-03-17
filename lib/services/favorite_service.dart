import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:rxdart/rxdart.dart';

class FavoriteService {
  FavoriteService._();
  static final FavoriteService _instance = FavoriteService._();
  static FavoriteService get instance => _instance;

  static const String favoritePlaylistId = 'favorites';
  static const String favoritePlaylistName = '我喜欢的音乐';

  final _favoritesChangedSubject = BehaviorSubject<void>.seeded(null);
  Stream<void> get favoritesChanged => _favoritesChangedSubject.asBroadcastStream();

  VoidCallback? onFavoriteChanged;

  Future<void> toggleFavorite(Song song) async {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);

      // Check if favorite playlist exists in Hive (check both by ID and name for backwards compatibility)
      var favoritePlaylistData = playlistBox.get(favoritePlaylistId) ?? playlistBox.get(favoritePlaylistName);
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

      // Save with both ID and proper structure
      await playlistBox.put(favoritePlaylistId, {
        'id': favoritePlaylistId,
        'name': favoritePlaylistName,
        'songs': favoriteSongs.map((s) => s.toJson()).toList(),
        'icon': 'favorite',
      });
      
      // Clean up old key if exists
      if (playlistBox.containsKey(favoritePlaylistName)) {
        await playlistBox.delete(favoritePlaylistName);
      }

      _favoritesChangedSubject.add(null);
      onFavoriteChanged?.call();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  bool isFavorite(Song song) {
    try {
      final playlistBox = Hive.box(AppConstants.playlistBox);
      final favoritePlaylistData = playlistBox.get(favoritePlaylistId) ?? playlistBox.get(favoritePlaylistName);

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
