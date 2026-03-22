import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
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
  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  final _queueSubject = BehaviorSubject<List<Song>>.seeded([]);
  final _isQueueLoopSubject = BehaviorSubject<bool>.seeded(false);
  final _queueIndexChangedSubject = BehaviorSubject<void>.seeded(null);
  
  bool _isTransitioning = false;
  StreamSubscription<Duration?>? _durationSubscription;
  int _currentQueueIndex = 0;

  Stream<Song?> get currentSongStream => _currentSongSubject.stream;
  Stream<List<Song>> get playlistStream => _playlistSubject.stream;
  Stream<int> get currentIndexStream => _currentIndexSubject.stream;
  Stream<RepeatMode> get repeatModeStream => _repeatModeSubject.stream;
  Stream<bool> get isShuffleStream => _isShuffleSubject.stream;
  Stream<bool> get isPreviewModeStream => _isPreviewModeSubject.stream;
  Stream<void> get recentPlaysChangedStream => _recentPlaysChangedSubject.stream;
  Stream<String?> get errorStream => _errorSubject.stream;
  Stream<List<Song>> get queueStream => _queueSubject.stream;
  Stream<bool> get isQueueLoopStream => _isQueueLoopSubject.stream;
  Stream<void> get queueIndexChangedStream => _queueIndexChangedSubject.stream;

  Song? get currentSong => _currentSongSubject.value;
  List<Song> get playlist => _playlistSubject.value;
  int get currentIndex => _currentIndexSubject.value;
  RepeatMode get repeatMode => _repeatModeSubject.value;
  bool get isShuffle => _isShuffleSubject.value;
  bool get isPreviewMode => _isPreviewModeSubject.value;
  List<Song> get queue => _queueSubject.value;
  bool get isQueueLoop => _isQueueLoopSubject.value;
  int get currentQueueIndex => _currentQueueIndex;

  VoidCallback? onRecentPlaysChanged;

  void setPreviewMode(bool value) {
    _isPreviewModeSubject.add(value);
  }
  
  void _emitError(String error) {
    _errorSubject.add(error);
    AppLogger.log('ERROR: $error');
  }
  
  void clearError() {
    _errorSubject.add(null);
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
    AppLogger.log('_prepareAudioSource: ${song.title}, id: ${song.id}');
    clearError();

    if (song.isLocal && song.localPath != null) {
      AppLogger.log('Setting local file: ${song.localPath}');
      try {
        await _audioPlayer.setFilePath(song.localPath!);
        AppLogger.log('Local file set successfully');
      } catch (e) {
        _emitError('无法播放本地文件: $e');
        rethrow;
      }
      return;
    }

    // 获取播放URL
    AppLogger.log('Fetching audio URL for song: ${song.id}');
    String? audioUrl;
    try {
      audioUrl = await MusicApiService.instance.getSongUrl(song.id);
    } catch (e) {
      _emitError('获取播放链接失败: $e');
      rethrow;
    }
    AppLogger.log('getSongUrl returned: $audioUrl');
    
    if (audioUrl == null || audioUrl.isEmpty) {
      _emitError('无法获取播放链接');
      throw Exception('Failed to get audio URL');
    }
    
    AppLogger.log('Got audio URL: $audioUrl');

    // 设置音频源
    final uri = Uri.parse(audioUrl);
    AppLogger.log('Parsed URI: $uri');
    
    AppLogger.log('Calling setUrl...');
    try {
      await _audioPlayer.setUrl(uri.toString());
      AppLogger.log('Audio source set successfully');
    } catch (e) {
      _emitError('无法加载音频: $e');
      rethrow;
    }
    
    final duration = _audioPlayer.duration;
    AppLogger.log('Duration after load: ${duration?.inSeconds ?? 0}s');
    
    if (duration == null || duration.inSeconds == 0) {
      _emitError('音频时长为0，可能无法播放');
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
      _emitError('没有选择歌曲');
      return;
    }

    clearError();
    final processingState = _audioPlayer.processingState;
    AppLogger.log('play() called, processingState: $processingState, hasAudioSource: ${_audioPlayer.audioSource != null}');

    try {
      // 如果音频源未准备好，先准备
      if (_audioPlayer.audioSource == null) {
        AppLogger.log('Preparing audio source...');
        await _prepareAudioSource(song);
        
        // 检查是否成功设置
        if (_audioPlayer.audioSource == null) {
          _emitError('无法加载音频源');
          return;
        }
      }
      
      if (processingState == ProcessingState.completed) {
        await _audioPlayer.seek(Duration.zero);
      }
      
      AppLogger.log('Calling _audioPlayer.play()');
      await _audioPlayer.play();
      AppLogger.log('play() success, playing: ${_audioPlayer.playing}');
    } catch (e, stack) {
      _emitError('播放失败: $e');
      AppLogger.log('Stack: $stack');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> playNext() async {
    // 优先从队列播放
    if (queue.isNotEmpty) {
      final nextSong = await getNextFromQueue();
      if (nextSong != null) {
        _currentSongSubject.add(nextSong);
        await _playSong(nextSong);
        await _saveCurrentSong(nextSong);
        return;
      }
    }
    
    // 队列为空，从播放列表播放
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
    // 如果播放超过3秒，重新开始当前歌曲
    if (_audioPlayer.position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
      return;
    }
    
    // 优先从队列播放上一首
    if (queue.isNotEmpty) {
      final prevSong = getPreviousFromQueue();
      if (prevSong != null) {
        _currentSongSubject.add(prevSong);
        await _playSong(prevSong);
        await _saveCurrentSong(prevSong);
        return;
      }
    }
    
    // 队列为空，从播放列表播放
    if (playlist.isEmpty) return;
    
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

  // ========== 队列管理方法 ==========

  final _isQueueLoadingSubject = BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isQueueLoadingStream => _isQueueLoadingSubject.stream;
  bool get isQueueLoading => _isQueueLoadingSubject.value;

  /// 加载相似歌曲到队列（包含当前歌曲在第一位）
  Future<void> loadSimilarToQueue(Song currentSong, {int limit = 24}) async {
    try {
      _isQueueLoadingSubject.add(true);
      AppLogger.log('Loading similar songs for: ${currentSong.id}');
      
      final similarSongs = await MusicApiService.instance.getSimilarSongs(
        currentSong.id,
        limit: limit,
      );
      
      // 过滤掉当前歌曲
      final filteredSongs = similarSongs.where((s) => s.id != currentSong.id).toList();
      
      // 构建队列：当前歌曲 + 相似歌曲
      final newQueue = [currentSong, ...filteredSongs];
      
      _queueSubject.add(newQueue);
      _currentQueueIndex = 0;
      _queueIndexChangedSubject.add(null);
      _isQueueLoadingSubject.add(false);
      
      AppLogger.log('Queue loaded: ${newQueue.length} songs, current at index 0');
    } catch (e) {
      AppLogger.log('Failed to load similar songs: $e');
      _isQueueLoadingSubject.add(false);
      _emitError('加载相似歌曲失败');
    }
  }

  /// 设置队列
  void setQueue(List<Song> songs, int currentIndex) {
    _queueSubject.add(songs);
    _currentQueueIndex = currentIndex;
    _queueIndexChangedSubject.add(null);
  }

  /// 清空队列
  void clearQueue() {
    _queueSubject.add([]);
    _currentQueueIndex = 0;
    _queueIndexChangedSubject.add(null);
  }

  /// 添加歌曲到队列末尾
  void addToQueue(Song song) {
    final currentQueue = List<Song>.from(queue);
    currentQueue.add(song);
    _queueSubject.add(currentQueue);
  }

  /// 从队列移除歌曲
  void removeFromQueue(int index) {
    final currentQueue = List<Song>.from(queue);
    if (index >= 0 && index < currentQueue.length) {
      currentQueue.removeAt(index);
      _queueSubject.add(currentQueue);
      
      // 调整当前索引
      if (_currentQueueIndex >= currentQueue.length) {
        _currentQueueIndex = currentQueue.length - 1;
      }
      _queueIndexChangedSubject.add(null);
    }
  }

  /// 拖动排序队列
  void reorderQueue(int oldIndex, int newIndex) {
    final currentQueue = List<Song>.from(queue);
    if (oldIndex < 0 || oldIndex >= currentQueue.length) return;
    
    final song = currentQueue.removeAt(oldIndex);
    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    currentQueue.insert(adjustedNewIndex, song);
    _queueSubject.add(currentQueue);
    
    // 更新当前播放索引
    if (_currentQueueIndex == oldIndex) {
      _currentQueueIndex = adjustedNewIndex;
    } else if (oldIndex < _currentQueueIndex && adjustedNewIndex >= _currentQueueIndex) {
      _currentQueueIndex--;
    } else if (oldIndex > _currentQueueIndex && adjustedNewIndex <= _currentQueueIndex) {
      _currentQueueIndex++;
    }
    _queueIndexChangedSubject.add(null);
  }

  /// 切换队列循环
  void toggleQueueLoop() {
    _isQueueLoopSubject.add(!isQueueLoop);
  }

  /// 从队列播放下一首
  Future<void> playFromQueue(int index) async {
    final currentQueue = queue;
    if (index < 0 || index >= currentQueue.length) return;
    
    _currentQueueIndex = index;
    _queueIndexChangedSubject.add(null);
    
    final song = currentQueue[index];
    await _playSong(song);
    await _saveCurrentSong(song);
  }

  /// 获取队列中的下一首歌曲
  Future<Song?> getNextFromQueue() async {
    final currentQueue = queue;
    if (currentQueue.isEmpty) return null;
    
    // 如果队列播放完，检查是否循环
    if (_currentQueueIndex >= currentQueue.length - 1) {
      if (isQueueLoop) {
        _currentQueueIndex = 0;
      } else {
        return null;
      }
    } else {
      _currentQueueIndex++;
    }
    
    _queueIndexChangedSubject.add(null);
    return queue[_currentQueueIndex];
  }

  /// 获取队列中的上一首歌曲
  Song? getPreviousFromQueue() {
    final currentQueue = queue;
    if (currentQueue.isEmpty) return null;
    
    if (_currentQueueIndex <= 0) {
      if (isQueueLoop) {
        _currentQueueIndex = currentQueue.length - 1;
      } else {
        return null;
      }
    } else {
      _currentQueueIndex--;
    }
    
    _queueIndexChangedSubject.add(null);
    return currentQueue[_currentQueueIndex];
  }

  void dispose() {
    _audioPlayer.dispose();
    _currentSongSubject.close();
    _playlistSubject.close();
    _currentIndexSubject.close();
    _repeatModeSubject.close();
    _isShuffleSubject.close();
    _isPreviewModeSubject.close();
    _queueSubject.close();
    _isQueueLoopSubject.close();
    _queueIndexChangedSubject.close();
    _isQueueLoadingSubject.close();
  }
}
