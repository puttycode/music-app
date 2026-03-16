part of 'library_bloc.dart';

abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadLocalMusic extends LibraryEvent {}

class RequestPermission extends LibraryEvent {}

class LoadPlaylists extends LibraryEvent {}

class RefreshPlaylists extends LibraryEvent {}

class CreatePlaylist extends LibraryEvent {
  final String name;
  const CreatePlaylist(this.name);

  @override
  List<Object?> get props => [name];
}

class DeletePlaylist extends LibraryEvent {
  final String playlistId;
  final String? legacyName;

  const DeletePlaylist({required this.playlistId, this.legacyName});

  @override
  List<Object?> get props => [playlistId, legacyName];
}

class RenamePlaylist extends LibraryEvent {
  final String playlistId;
  final String oldName;
  final String newName;

  const RenamePlaylist({
    required this.playlistId,
    required this.oldName,
    required this.newName,
  });

  @override
  List<Object?> get props => [playlistId, oldName, newName];
}
