import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

class LocalMusicScanner {
  /// Scan the device for local music files and return a list of Song objects.
  /// Only scans common audio file extensions.
  static Future<List<Song>> scan() async {
    final List<Song> songs = [];
    try {
      // Get the external storage directory (where music is usually stored)
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        return songs;
      }

      // Define audio file extensions to look for
      const audioExtensions = {
        '.mp3',
        '.wav',
        '.flac',
        '.aac',
        '.ogg',
        '.m4a',
        '.3gp',
      };

      // Recursively scan the directory
      await _scanDirectory(externalDir, audioExtensions, songs);
    } catch (e) {
      // Ignore errors, return empty list
    }
    return songs;
  }

  /// Recursively scan a directory for audio files.
  static Future<void> _scanDirectory(
      Directory dir,
      Set<String> extensions,
      List<Song> songs,
      ) async {
    try {
      if (!dir.existsSync()) {
        return;
      }

      final entities = dir.listSync(recursive: false, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final lowerPath = entity.path.toLowerCase();
          if (extensions.any((ext) => lowerPath.endsWith(ext))) {
            // Try to extract metadata from the file name as a fallback
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
            
            // Simple parsing: assume format "Artist - Title" or just "Title"
            String title = nameWithoutExt;
            String artist = 'Unknown Artist';
            
            if (nameWithoutExt.contains(' - ')) {
              final parts = nameWithoutExt.split(' - ');
              if (parts.length >= 2) {
                artist = parts[0].trim();
                title = parts[1].trim();
              }
            }

            songs.add(Song(
              id: DateTime.now().millisecondsSinceEpoch.negate().abs(), // Temporary ID
              title: title,
              artist: artist,
              album: 'Unknown Album',
              albumArt: null, // We don't have album art from file scan
              audioUrl: null, // We'll use localPath instead
              duration: const Duration(seconds: 0), // We don't have duration from scan
              isLocal: true,
              localPath: entity.path,
              lyrics: null,
            ));
          }
        } else if (entity is Directory) {
          // Recursively scan subdirectories
          await _scanDirectory(entity, extensions, songs);
        }
      }
    } catch (e) {
      // Ignore errors in subdirectories
    }
  }
}