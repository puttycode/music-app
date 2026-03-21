import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/utils/app_logger.dart';
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
  final _isPreviewModeSubject = BehaviorSubject<bool>.seeded(false);
  final _recentPlaysChangedSubject = BehaviorSubject<void>.seeded(null);
  
  bool _isTransitioning = false;
  StreamSubscription<Duration?>? _durationSubscription;

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
    
    // Listen for duration updates and save to recent plays
    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (duration != null && duration.inSeconds > 0) {
        _updateSongDuration(duration);
      }
    });
  }
  
  void _updateSongDuration(Duration duration) {
    final song = currentSong;
    if (song == null) return;
    
    // Only update if duration was previously unknown or zero
    if (song.duration.inSeconds > 0 && song.duration.inSeconds < 3600) return;
    
    AppLogger.log('Updating song duration: ${song.title} -> ${duration.inSeconds}s');
    
    // Update current song
    final updatedSong = song.copyWith(duration: duration);
    _currentSongSubject.add(updatedSong);
    
    // Update in recent plays
    _updateDurationInRecentPlays(song.id, duration);
    
    // Update in playlist if present
    final currentPlaylist = playlist;
    final playlistIndex = currentPlaylist.indexWhere((s) => s.id == song.id);
    if (playlistIndex >= 0) {
      currentPlaylist[playlistIndex] = updatedSong;
      _playlistSubject.add(List.from(currentPlaylist));
    }
  }
  
Future<void> _updateDurationInRecentPlays(String songId, Duration duration) async {
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      
      for (var key in recentBox.keys.toList()) {
        final item = recentBox.get(key);
        if (item is Map && item['id']?.toString() == songId) {
          item['duration'] = duration.inMilliseconds;
          await recentBox.put(key, item);
          AppLogger.log('Updated duration in recent plays for song $songId');
          break;
        }
      }
    } catch (e) {
      AppLogger.log('Error updating duration in recent plays: $e');
    }
  }

  void _onSongComplete() {
    if (_isTransitioning) {
      AppLogger.log('Skipping _onSongComplete: already transitioning');
      return;
    }
    
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
          // End of playlist - reset to beginning of current song
          AppLogger.log('End of playlist, resetting position');
          _audioPlayer.seek(Duration.zero);
        }
        break;
    }
  }

  Future<void> setPlaylist(List<Song> songs, int startIndex, {bool autoPlay = true}) async {
    AppLogger.log('setPlaylist called: ${songs.length} songs, startIndex: $startIndex, autoPlay: $autoPlay');
    if (songs.isEmpty) return;
    
    _playlistSubject.add(songs);
    _currentIndexSubject.add(startIndex);
    var song = songs[startIndex];
    AppLogger.log('Current song: ${song.title} - ${song.artist}, url: ${song.audioUrl}');
    _currentSongSubject.add(song);
    
    if (autoPlay) {
      await _playSong(song);
      final actualDuration = _audioPlayer.duration;
      if (actualDuration != null && song.duration != actualDuration) {
        song = song.copyWith(duration: actualDuration);
        _currentSongSubject.add(song);
      }
      await _saveToRecentPlays(song);
      await _saveCurrentSong(song);
    } else {
      await _saveToRecentPlays(song);
      await _saveCurrentSong(song);
      AppLogger.log('AutoPlay disabled, preparing audio source');
      await _prepareAudioSource(song);
    }
  }

  Future<void> _prepareAudioSource(Song song) async {
    try {
      AppLogger.log('_prepareAudioSource: ${song.title}, id: ${song.id}');

      if (song.isLocal && song.localPath != null) {
        AppLogger.log('Setting local file: ${song.localPath}');
        final audioSource = AudioSource.file(
          song.localPath!,
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artUri: song.albumArt != null ? Uri.tryParse(song.albumArt!) : null,
          ),
        );
        await _audioPlayer.setAudioSource(audioSource);
        AppLogger.log('Local file set successfully');
        return;
      }

      // 获取播放URL
      AppLogger.log('Fetching audio URL for song: ${song.id}');
      final audioUrl = await MusicApiService.instance.getSongUrl(song.id);
      
      if (audioUrl == null || audioUrl.isEmpty) {
        AppLogger.log('ERROR: Failed to get audio URL');
        return;
      }
      
      AppLogger.log('Got audio URL: $audioUrl');

      // 设置音频源
      final uri = Uri.parse(audioUrl);
      AppLogger.log('Parsed URI: $uri');
      
      final audioSource = AudioSource.uri(
        uri,
        tag: MediaItem(
          id: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          artUri: song.albumArt != null ? Uri.tryParse(song.albumArt!) : null,
        ),
      );
      
      await _audioPlayer.setAudioSource(audioSource);
      AppLogger.log('Audio source set successfully');
      
      final duration = _audioPlayer.duration;
      AppLogger.log('Duration after load: ${duration?.inSeconds ?? 0}s');
      
    } catch (e, stack) {
      AppLogger.log('Error preparing audio source: $e');
      AppLogger.log('Stack trace: $stack');
    }
  }

  Future<void> _saveCurrentSong(Song song) async {
    try {
      final playbackBox = Hive.box(AppConstants.playbackBox);
      final data = song.toJson();
      data['savedPosition'] = _audioPlayer.position.inMilliseconds;
      await playbackBox.put('currentSong', data);
      AppLogger.log('Saved current song: ${song.title} at position ${_audioPlayer.position}');
    } catch (e) {
      AppLogger.log('Error saving current song: $e');
    }
  }

  Future<Song?> restoreCurrentSong() async {
    try {
      final playbackBox = Hive.box(AppConstants.playbackBox);
      final songData = playbackBox.get('currentSong');
      if (songData is Map) {
        final song = Song.fromLocal(Map<String, dynamic>.from(songData));
        AppLogger.log('Restored current song: ${song.title}');
        return song;
      }
      return null;
    } catch (e) {
      AppLogger.log('Error restoring current song: $e');
      return null;
    }
  }

  Future<Duration?> restorePosition() async {
    try {
      final playbackBox = Hive.box(AppConstants.playbackBox);
      final songData = playbackBox.get('currentSong');
      if (songData is Map && songData['savedPosition'] != null) {
        return Duration(milliseconds: songData['savedPosition'] as int);
      }
      return null;
    } catch (e) {
      AppLogger.log('Error restoring position: $e');
      return null;
    }
  }

  Future<void> _saveToRecentPlays(Song song) async {
    try {
      final recentBox = Hive.box(AppConstants.recentPlaysBox);
      
      // Remove existing song with same ID
      final existingKeys = recentBox.keys.where((key) {
        final item = recentBox.get(key);
        if (item is Map) {
          return item['id']?.toString() == song.id;
        }
        return false;
      }).toList();
      for (var key in existingKeys) {
        await recentBox.delete(key);
      }
      
      // Update song with playedAt timestamp
      final songWithPlayedAt = song.copyWith(playedAt: DateTime.now());
      
      // Save as JSON map with song.id as key
      await recentBox.put('song_${song.id}', songWithPlayedAt.toJson());
      
      if (recentBox.length > AppConstants.recentPlaysMax) {
        // Find and remove the oldest song by playedAt timestamp
        final allSongs = <MapEntry<dynamic, Song>>[];
        for (final key in recentBox.keys) {
          final item = recentBox.get(key);
          if (item is Map) {
            final s = Song.fromLocal(Map<String, dynamic>.from(item));
            allSongs.add(MapEntry(key, s));
          }
        }
        
        // Sort by playedAt (oldest first)
        allSongs.sort((a, b) {
          final aTime = a.value.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.value.playedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        });
        
        // Remove the oldest
        if (allSongs.isNotEmpty) {
          await recentBox.delete(allSongs.first.key);
        }
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
    _isTransitioning = true;
    try {
      AppLogger.log('_playSong: ${song.title}');
      await _prepareAudioSource(song);
      AppLogger.log('Starting playback');
      await _audioPlayer.play();
      AppLogger.log('Playback started');
    } catch (e) {
      AppLogger.log('Error playing song: $e');
      print('Error playing song: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> play() async {
    final song = currentSong;
    if (song == null) {
      AppLogger.log('play() called but no current song');
      return;
    }

    final processingState = _audioPlayer.processingState;
    AppLogger.log('play() called, processingState: $processingState, hasAudioSource: ${_audioPlayer.audioSource != null}');

    try {
      if (processingState == ProcessingState.idle || _audioPlayer.audioSource == null) {
        AppLogger.log('Preparing audio source first...');
        await _prepareAudioSource(song);
      }
      
      if (processingState == ProcessingState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }
      
      await _audioPlayer.play();
      AppLogger.log('play() success');
    } catch (e) {
      AppLogger.log('play() error: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> playNext() async {
    if (playlist.isEmpty) return;
    
    int nextIndex;
    if (isShuffle && playlist.length > 1) {
      final random = DateTime.now().millisecondsSinceEpoch;
      nextIndex = (random % (playlist.length - 1));
      if (nextIndex >= currentIndex) nextIndex++;
    } else {
      nextIndex = (currentIndex + 1) % playlist.length;
    }
    
    _currentIndexSubject.add(nextIndex);
    var song = playlist[nextIndex];
    _currentSongSubject.add(song);
    await _playSong(song);
    final actualDuration = _audioPlayer.duration;
    if (actualDuration != null && song.duration != actualDuration) {
      song = song.copyWith(duration: actualDuration);
      _currentSongSubject.add(song);
    }
    await _saveToRecentPlays(song);
    await _saveCurrentSong(song);
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
    var song = playlist[prevIndex];
    _currentSongSubject.add(song);
    await _playSong(song);
    final actualDuration = _audioPlayer.duration;
    if (actualDuration != null && song.duration != actualDuration) {
      song = song.copyWith(duration: actualDuration);
      _currentSongSubject.add(song);
    }
    await _saveToRecentPlays(song);
    await _saveCurrentSong(song);
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
