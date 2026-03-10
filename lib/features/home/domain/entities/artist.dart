import 'package:equatable/equatable.dart';

class Artist extends Equatable {
  final int id;
  final String name;
  final String? image;
  final int? fans;
  final String? bio;
  final int? trackCount;
  final int? albumCount;

  const Artist({
    required this.id,
    required this.name,
    this.image,
    this.fans,
    this.bio,
    this.trackCount,
    this.albumCount,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Artist',
      image: json['picture_medium'] ?? json['picture'],
      fans: json['nb_fan'] ?? json['fans'],
      bio: json['bio'],
      trackCount: json['nb_track'],
      albumCount: json['nb_album'],
    );
  }

  @override
  List<Object?> get props => [id, name];
}
