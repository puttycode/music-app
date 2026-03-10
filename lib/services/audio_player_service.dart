import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../features/player/domain/entities/song.dart';

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

  Stream<Song?> get currentSongStream => _currentSongSubject.stream;
  Stream<List<Song>> get playlistStream => _playlistSubject.stream;
  Stream<int> get currentIndexStream => _currentIndexSubject.stream;
  Stream<RepeatMode> get repeatModeStream => _repeatModeSubject.stream;
  Stream<bool> get isShuffleStream => _isShuffleSubject.stream;

  Song? get currentSong => _currentSongSubject.value;
  List<Song> get playlist => _playlistSubject.value;
  int get currentIndex => _currentIndexSubject.value;
  RepeatMode get repeatMode => _repeatModeSubject.value;
  bool get isShuffle => _isShuffleSubject.value;

  AudioPlayerService._() {
    _audioPlayer = AudioPlayer();
    _init();
  }

  void _init() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
    });
  }

  void _onSongComplete() {
    switch (repeatMode) {
      case RepeatMode.one:
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
        break;
      case RepeatMode.all:
        playNext();
        break;
      case RepeatMode.off:
        if (currentIndex < playlist.length - 1) {
          playNext();
        }
        break;
    }
  }

  Future<void> setPlaylist(List<Song> songs, int startIndex) async {
    _playlistSubject.add(songs);
    _currentIndexSubject.add(startIndex);
    _currentSongSubject.add(songs[startIndex]);
    await _playSong(songs[startIndex]);
  }

  Future<void> _playSong(Song song) async {
    try {
      if (song.isLocal && song.localPath != null) {
        await _audioPlayer.setFilePath(song.localPath!);
      } else if (song.audioUrl != null) {
        await _audioPlayer.setUrl(song.audioUrl!);
      }
      await _audioPlayer.play();
    } catch (e) {
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
  }
}
