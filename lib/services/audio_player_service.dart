import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../features/player/domain/entities/song.dart';
import '../core/constants/app_constants.dart';
import 'music_api_service.dart';

enum RepeatMode { off, one, all }

class AudioPlayerService {
  static AudioPlayerService? _instance;
  static AudioPlayerService get instance => _instance ??= AudioPlayerService._();

  late AudioPlayer _audioPlayer;
  
  final _currentSongSubject = BehaviorSubject<Song?>.seeded(null);
  final _playlistSubject = BehaviorSubject<List<Song>>.seeded([]);
  final _currentIndexSubject = BehaviorSubject<int>.seeded(0);
  final _repeatModeSubject = BehaviorSubject<RepeatMode>.seeded(RepeatMode.off);
  final _isShuffleSubject = BehaviorSubject<bool>.seeded(false);
  final _isPreviewModeSubject = BehaviorSubject<bool>.seeded(true);
  final _recentPlaysChangedSubject = BehaviorSubject<void>.seeded(null);

  Stream<Song?> get currentSongStream => _currentSongSubject.stream;
  Stream<List<Song>> get playlistStream => _playlistSubject.stream;
  Stream<int> get currentIndexStream => _currentIndexSubject.stream;
  Stream<RepeatMode> get repeatModeStream => _repeatModeSubject.stream;
  Stream<bool> get isShuffleStream => _isShuffleSubject.stream;
  Stream<bool> get isPreviewModeStream => _isPreviewModeSubject.stream;
  Stream<void> get recentPlaysChangedStream => _recentPlaysChangedSubject.stream;

  Song? get currentSong => _currentSongSubject.value;
  List<Song> get playlist => _playlistSubject.value;
  int get currentIndex => _currentIndexSubject.value;
  RepeatMode get repeatMode => _repeatModeSubject.value;
  bool get isShuffle => _isShuffleSubject.value;
  bool get isPreviewMode => _isPreviewModeSubject.value;

  // Callback for library to refresh recent plays
  VoidCallback? onRecentPlaysChanged;

  void setPreviewMode(bool value) {
    _isPreviewModeSubject.add(value);
  }

  AudioPlayerService._() {
    _audioPlayer = AudioPlayer();
    _init();
  }

  void _init() {
    _audioPlayer.playerStateStream.listen((state) {
      AppLogger.log('Player state: playing=${state.playing}, processing=${state.processingState}');
      if (state.processingState == ProcessingState.completed) {
        AppLogger.log('Song completed, repeatMode=$repeatMode');
        _onSongComplete();
      }
    });
  }

  void _onSongComplete() {
    if (isPreviewMode) {
      return;
    }

    AppLogger.log('Processing repeat mode: $repeatMode');
    switch (repeatMode) {
      case RepeatMode.one:
        AppLogger.log('Repeating current song');
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
        break;
      case RepeatMode.all:
        AppLogger.log('Playing next in loop');
        playNext();
        break;
      case RepeatMode.off:
        if (currentIndex < playlist.length - 1) {
          AppLogger.log('Playing next song');
          playNext();
        } else {
          AppLogger.log('End of playlist, stopping');
        }
        break;
    }
  }

  Future<void> setPlaylist(List<Song> songs, int startIndex) async {
    AppLogger.log('setPlaylist called: ${songs.length} songs, startIndex: $startIndex');
    if (songs.isEmpty) return;
    
    _playlistSubject.add(songs);
    _currentIndexSubject.add(startIndex);
    final song = songs[startIndex];
    AppLogger.log('Playing song: ${song.title} - ${song.artist}, url: ${song.audioUrl}');
    _currentSongSubject.add(song);
    await _saveToRecentPlays(song);
    await _playSong(song);
  }

  Future<void> _saveToRecentPlays(Song song) async {
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      
      // Remove existing song with same ID
      final existingKeys = recentBox.keys.where((key) {
        final item = recentBox.get(key);
        if (item is Map) {
          return item['id'] == song.id;
        }
        return false;
      }).toList();
      for (var key in existingKeys) {
        await recentBox.delete(key);
      }
      
      // Update song with playedAt timestamp
      final songWithPlayedAt = song.copyWith(playedAt: DateTime.now());
      
      // Save as JSON map
      await recentBox.put(songWithPlayedAt.hashCode, songWithPlayedAt.toJson());
      
      if (recentBox.length > AppConstants.recentPlaysMax) {
        final keys = recentBox.keys.toList();
        await recentBox.delete(keys.first);
      }
      
      AppLogger.log('Saved to recent plays: ${songWithPlayedAt.title}');
      
      // Notify listeners
      _recentPlaysChangedSubject.add(null);
      onRecentPlaysChanged?.call();
    } catch (e) {
      AppLogger.log('Error saving to recent: $e');
    }
  }

  Future<void> _playSong(Song song) async {
    try {
      AppLogger.log('_playSong: ${song.title}, url: ${song.audioUrl}');
      if (song.isLocal && song.localPath != null) {
        await _audioPlayer.setFilePath(song.localPath!);
      } else if (song.audioUrl != null) {
        AppLogger.log('Setting URL: ${song.audioUrl}');
        await _audioPlayer.setUrl(song.audioUrl!);
      }
      AppLogger.log('Starting playback');
      await _audioPlayer.play();
      AppLogger.log('Playback started');
    } catch (e) {
      AppLogger.log('Error playing song: $e');
      print('Error playing song: $e');
    }
  }

  Future<void> play() async {
    await _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> playNext() async {
    if (playlist.isEmpty) return;
    
    int nextIndex;
    if (isShuffle) {
      nextIndex = (currentIndex + 1) % playlist.length;
    } else {
      nextIndex = (currentIndex + 1) % playlist.length;
    }
    
    _currentIndexSubject.add(nextIndex);
    _currentSongSubject.add(playlist[nextIndex]);
    await _playSong(playlist[nextIndex]);
    await _saveToRecentPlays(playlist[nextIndex]);
  }

  Future<void> playPrevious() async {
    if (playlist.isEmpty) return;
    
    if (_audioPlayer.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }
    
    int prevIndex = currentIndex - 1;
    if (prevIndex < 0) prevIndex = playlist.length - 1;
    
    _currentIndexSubject.add(prevIndex);
    _currentSongSubject.add(playlist[prevIndex]);
    await _playSong(playlist[prevIndex]);
    await _saveToRecentPlays(playlist[prevIndex]);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> seekRelative(Duration offset) async {
    final newPosition = _audioPlayer.position + offset;
    await seek(newPosition.isNegative ? Duration.zero : newPosition);
  }

  void toggleRepeat() {
    final modes = RepeatMode.values;
    final currentModeIndex = modes.indexOf(repeatMode);
    final nextIndex = (currentModeIndex + 1) % modes.length;
    _repeatModeSubject.add(modes[nextIndex]);
  }

  void toggleShuffle() {
    _isShuffleSubject.add(!isShuffle);
  }

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  void dispose() {
    _audioPlayer.dispose();
    _currentSongSubject.close();
    _playlistSubject.close();
    _currentIndexSubject.close();
    _repeatModeSubject.close();
    _isShuffleSubject.close();
    _isPreviewModeSubject.close();
  }
}
