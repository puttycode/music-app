import 'package:equatable/equatable.dart';

class Artist extends Equatable {
  final String id;
  final String name;
  final String? avatar;
  final int? musicNum;

  const Artist({
    required this.id,
    required this.name,
    this.avatar,
    this.musicNum,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['rid']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Artist',
      avatar: json['pic']?.toString() ?? json['pic70']?.toString() ?? json['pic120']?.toString(),
      musicNum: int.tryParse(json['musicNum']?.toString() ?? '0'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'musicNum': musicNum,
    };
  }

  @override
  List<Object?> get props => [id, name, avatar, musicNum];
}
