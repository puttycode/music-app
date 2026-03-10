import 'package:equatable/equatable.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/services/audio_player_service.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlaySong extends PlayerEvent {
  final Song song;
  final List<Song>? playlist;
  final int? index;

  const PlaySong({required this.song, this.playlist, this.index});

  @override
  List<Object?> get props => [song, playlist, index];
}

class PauseSong extends PlayerEvent {}

class ResumeSong extends PlayerEvent {}

class PlayNext extends PlayerEvent {}

class PlayPrevious extends PlayerEvent {}

class SeekTo extends PlayerEvent {
  final Duration position;

  const SeekTo(this.position);

  @override
  List<Object?> get props => [position];
}

class SeekRelative extends PlayerEvent {
  final Duration offset;

  const SeekRelative(this.offset);

  @override
  List<Object?> get props => [offset];
}

class ToggleRepeat extends PlayerEvent {}

class ToggleShuffle extends PlayerEvent {}

class PlayerState extends Equatable {
  final Song? currentSong;
  final List<Song> playlist;
  final int currentIndex;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final RepeatMode repeatMode;
  final bool isShuffle;

  const PlayerState({
    this.currentSong,
    this.playlist = const [],
    this.currentIndex = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.repeatMode = RepeatMode.off,
    this.isShuffle = false,
  });

  PlayerState copyWith({
    Song? currentSong,
    List<Song>? playlist,
    int? currentIndex,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    RepeatMode? repeatMode,
    bool? isShuffle,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      repeatMode: repeatMode ?? this.repeatMode,
      isShuffle: isShuffle ?? this.isShuffle,
    );
  }

  @override
  List<Object?> get props => [
    currentSong,
    playlist,
    currentIndex,
    position,
    duration,
    isPlaying,
    isLoading,
    repeatMode,
    isShuffle,
  ];
}
