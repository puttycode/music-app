import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

class LocalMusicScanner {
  static Future<List<Song>> scan() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      return [];
    }

    final List<Song> songs = [];
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        return songs;
      }

      const audioExtensions = {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.3gp'};
      await _scanDirectory(externalDir, audioExtensions, songs);
    } catch (e) {
      // Ignore errors
    }
    return songs;
  }

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
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
            
            String title = nameWithoutExt;
            String artist = 'Unknown Artist';
            String album = 'Unknown Album';
            
            if (nameWithoutExt.contains(' - ')) {
              final parts = nameWithoutExt.split(' - ');
              if (parts.length >= 2) {
                artist = parts[0].trim();
                title = parts[1].trim();
              }
            }

            songs.add(Song(
              id: entity.path.hashCode,
              title: title,
              artist: artist,
              album: album,
              albumArt: null,
              audioUrl: null,
              duration: const Duration(seconds: 0),
              isLocal: true,
              localPath: entity.path,
              lyrics: null,
            ));
          }
        } else if (entity is Directory) {
          await _scanDirectory(entity, extensions, songs);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
