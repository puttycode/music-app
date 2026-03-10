import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/audio_player_service.dart';
import 'player_event_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayerService _audioService;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _currentSongSubscription;

  PlayerBloc({AudioPlayerService? audioService})
      : _audioService = audioService ?? AudioPlayerService.instance,
        super(const PlayerState()) {
    on<PlaySong>(_onPlaySong);
    on<PauseSong>(_onPauseSong);
    on<ResumeSong>(_onResumeSong);
    on<PlayNext>(_onPlayNext);
    on<PlayPrevious>(_onPlayPrevious);
    on<SeekTo>(_onSeekTo);
    on<SeekRelative>(_onSeekRelative);
    on<ToggleRepeat>(_onToggleRepeat);
    on<ToggleShuffle>(_onToggleShuffle);

    _initStreams();
  }

  void _initStreams() {
    _playerStateSubscription = _audioService.playerStateStream.listen((playerState) {
      emit(state.copyWith(
        isPlaying: playerState.playing,
        isLoading: playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering,
      ));
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      emit(state.copyWith(position: position));
    });

    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (duration != null) {
        emit(state.copyWith(duration: duration));
      }
    });

    _currentSongSubscription = _audioService.currentSongStream.listen((song) {
      emit(state.copyWith(
        currentSong: song,
        playlist: _audioService.playlist,
        currentIndex: _audioService.currentIndex,
        repeatMode: _audioService.repeatMode,
        isShuffle: _audioService.isShuffle,
      ));
    });
  }

  Future<void> _onPlaySong(PlaySong event, Emitter<PlayerState> emit) async {
    emit(state.copyWith(isLoading: true));
    
    if (event.playlist != null) {
      await _audioService.setPlaylist(
        event.playlist!,
        event.index ?? 0,
      );
    } else {
      await _audioService.setPlaylist([event.song], 0);
    }
  }

  Future<void> _onPauseSong(PauseSong event, Emitter<PlayerState> emit) async {
    await _audioService.pause();
  }

  Future<void> _onResumeSong(ResumeSong event, Emitter<PlayerState> emit) async {
    await _audioService.play();
  }

  Future<void> _onPlayNext(PlayNext event, Emitter<PlayerState> emit) async {
    await _audioService.playNext();
  }

  Future<void> _onPlayPrevious(PlayPrevious event, Emitter<PlayerState> emit) async {
    await _audioService.playPrevious();
  }

  Future<void> _onSeekTo(SeekTo event, Emitter<PlayerState> emit) async {
    await _audioService.seek(event.position);
  }

  Future<void> _onSeekRelative(SeekRelative event, Emitter<PlayerState> emit) async {
    await _audioService.seekRelative(event.offset);
  }

  void _onToggleRepeat(ToggleRepeat event, Emitter<PlayerState> emit) {
    _audioService.toggleRepeat();
  }

  void _onToggleShuffle(ToggleShuffle event, Emitter<PlayerState> emit) {
    _audioService.toggleShuffle();
  }

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _currentSongSubscription?.cancel();
    return super.close();
  }
}
