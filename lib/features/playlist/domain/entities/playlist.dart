import 'package:equatable/equatable.dart';
import 'song.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String? coverImage;
  final List<Song> songs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverImage,
    this.songs = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      description: json['description'],
      coverImage: json['coverImage'],
      songs: json['songs'] != null 
          ? (json['songs'] as List).map((s) => Song.fromLocal(s)).toList()
          : [],
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImage': coverImage,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverImage,
    List<Song>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, songs];
}
