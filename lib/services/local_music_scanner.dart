import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:music_app/features/player/domain/entities/song.dart';

class LocalMusicScanner {
  static Future<List<Song>> scan() async {
    final status = await _requestAudioPermission();
    if (!status.isGranted) {
      return [];
    }

    final List<Song> songs = [];
    try {
      const audioExtensions = {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a', '.3gp'};
      final settingsBox = Hive.box('settings');
      final configuredDownloadPath = settingsBox.get('downloadPath');
      final directories = <Directory>[];
      final seenPaths = <String>{};

      // Prioritize download path
      if (configuredDownloadPath is String && configuredDownloadPath.isNotEmpty) {
        directories.add(Directory(configuredDownloadPath));
      }

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        directories.add(externalDir);
      }

      for (final directory in directories) {
        if (seenPaths.add(directory.path) && directory.existsSync()) {
          await _scanDirectory(directory, audioExtensions, songs, maxDepth: 5);
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return songs;
  }

  static Future<PermissionStatus> _requestAudioPermission() async {
    if (Platform.isAndroid) {
      final audioStatus = await Permission.audio.request();
      if (audioStatus.isGranted) {
        return audioStatus;
      }
    }

    return Permission.storage.request();
  }

  static Future<void> _scanDirectory(
      Directory dir,
      Set<String> extensions,
      List<Song> songs,
      {int currentDepth = 0, int maxDepth = 5},
      ) async {
    try {
      if (!dir.existsSync() || currentDepth > maxDepth) {
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
        } else if (entity is Directory && currentDepth < maxDepth) {
          // Skip common non-music directories
          final dirName = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          if (!['android', 'data', 'obb', 'system', 'cache'].contains(dirName)) {
            await _scanDirectory(
              entity,
              extensions,
              songs,
              currentDepth: currentDepth + 1,
              maxDepth: maxDepth,
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
