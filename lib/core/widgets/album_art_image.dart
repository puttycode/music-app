import 'package:flutter/material.dart';

class AlbumArtImage extends StatelessWidget {
  final String? albumArt;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AlbumArtImage({
    Key? key,
    this.albumArt,
    this.size = 48,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final imageWidth = width ?? size;
    final imageHeight = height ?? size;
    
    if (albumArt == null || albumArt!.isEmpty) {
      return _buildDefault(imageWidth, imageHeight);
    }
    
    return Image.network(
      albumArt!,
      width: imageWidth,
      height: imageHeight,
      fit: fit,
      errorBuilder: (_, __, ___) => _buildDefault(imageWidth, imageHeight),
    );
  }

  Widget _buildDefault(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.2),
      child: Icon(Icons.music_note, size: (width + height) / 4),
    );
  }
}