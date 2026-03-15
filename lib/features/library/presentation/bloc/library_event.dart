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
  final String name;
  const DeletePlaylist(this.name);

  @override
  List<Object?> get props => [name];
}
