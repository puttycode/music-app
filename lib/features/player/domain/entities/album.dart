import 'package:equatable/equatable.dart';

class Album extends Equatable {
  final String id;
  final String name;
  final String? artist;
  final String? cover;
  final int? songNum;

  const Album({
    required this.id,
    required this.name,
    this.artist,
    this.cover,
    this.songNum,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['albumid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['album']?.toString() ?? json['name']?.toString() ?? 'Unknown Album',
      artist: json['artist']?.toString(),
      cover: json['pic']?.toString(),
      songNum: int.tryParse(json['songNum']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'cover': cover,
      'songNum': songNum,
    };
  }

  @override
  List<Object?> get props => [id, name, artist, cover, songNum];
}
