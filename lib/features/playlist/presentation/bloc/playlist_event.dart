part of 'playlist_bloc.dart';

abstract class PlaylistEvent extends Equatable {
  const PlaylistEvent();

  @override
  List<Object?> get props => [];
}

class LoadPlaylists extends PlaylistEvent {}

class CreatePlaylist extends PlaylistEvent {
  final String name;

  const CreatePlaylist(this.name);

  @override
  List<Object?> get props => [name];
}

class DeletePlaylist extends PlaylistEvent {
  final String id;

  const DeletePlaylist(this.id);

  @override
  List<Object?> get props => [id];
}

class AddSongToPlaylist extends PlaylistEvent {
  final String playlistId;
  final Song song;

  const AddSongToPlaylist({required this.playlistId, required this.song});

  @override
  List<Object?> get props => [playlistId, song];
}

class RemoveSongFromPlaylist extends PlaylistEvent {
  final String playlistId;
  final int songId;

  const RemoveSongFromPlaylist({required this.playlistId, required this.songId});

  @override
  List<Object?> get props => [playlistId, songId];
}
