import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
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
      add(_UpdatePlayerState(
        isPlaying: playerState.playing,
        isLoading: playerState.processingState == ProcessingState.loading ||
            playerState.processingState == ProcessingState.buffering,
      ));
    });

    _positionSubscription = _audioService.positionStream.listen((position) {
      add(_UpdatePosition(position));
    });

    _durationSubscription = _audioService.durationStream.listen((duration) {
      if (duration != null) {
        add(_UpdateDuration(duration));
      }
    });

    _currentSongSubscription = _audioService.currentSongStream.listen((song) {
      AppLogger.log('PlayerBloc received song: ${song?.title} - ${song?.artist}');
      add(_UpdateCurrentSong(song));
    });
  }

  Future<void> _onPlaySong(PlaySong event, Emitter<PlayerState> emit) async {
    AppLogger.log('_onPlaySong called: ${event.song.title} - ${event.song.artist}');
    emit(state.copyWith(isLoading: true, currentSong: event.song));
    
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

  void _onUpdatePlayerState(_UpdatePlayerState event, Emitter<PlayerState> emit) {
    emit(state.copyWith(isPlaying: event.isPlaying, isLoading: event.isLoading));
  }

  void _onUpdatePosition(_UpdatePosition event, Emitter<PlayerState> emit) {
    emit(state.copyWith(position: event.position));
  }

  void _onUpdateDuration(_UpdateDuration event, Emitter<PlayerState> emit) {
    emit(state.copyWith(duration: event.duration));
  }

  void _onUpdateCurrentSong(_UpdateCurrentSong event, Emitter<PlayerState> emit) {
    emit(state.copyWith(
      currentSong: event.song,
      playlist: _audioService.playlist,
      currentIndex: _audioService.currentIndex,
      repeatMode: _audioService.repeatMode,
      isShuffle: _audioService.isShuffle,
    ));
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

class _UpdatePlayerState extends PlayerEvent {
  final bool isPlaying;
  final bool isLoading;
  const _UpdatePlayerState({required this.isPlaying, required this.isLoading});
}

class _UpdatePosition extends PlayerEvent {
  final Duration position;
  const _UpdatePosition(this.position);
}

class _UpdateDuration extends PlayerEvent {
  final Duration duration;
  const _UpdateDuration(this.duration);
}

class _UpdateCurrentSong extends PlayerEvent {
  final Song? song;
  const _UpdateCurrentSong(this.song);
}
