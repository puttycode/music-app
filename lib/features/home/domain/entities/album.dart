import 'package:equatable/equatable.dart';
import 'artist.dart';

class Album extends Equatable {
  final int id;
  final String title;
  final String? cover;
  final String? coverMedium;
  final String? coverBig;
  final Artist? artist;
  final int? releaseDate;
  final int? trackCount;

  const Album({
    required this.id,
    required this.title,
    this.cover,
    this.coverMedium,
    this.coverBig,
    this.artist,
    this.releaseDate,
    this.trackCount,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown Album',
      cover: json['cover'] ?? json['cover_small'],
      coverMedium: json['cover_medium'] ?? json['cover'],
      coverBig: json['cover_big'],
      artist: json['artist'] != null ? Artist.fromJson(json['artist']) : null,
      releaseDate: json['release_date'] != null 
          ? int.tryParse(json['release_date'].toString().replaceAll('-', ''))
          : null,
      trackCount: json['nb_tracks'],
    );
  }

  @override
  List<Object?> get props => [id, title];
}
