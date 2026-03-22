import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/app.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/services/audio_player_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(AppConstants.playlistBox),
    Hive.openBox(AppConstants.recentPlaysBox),
    Hive.openBox(AppConstants.settingsBox),
    Hive.openBox(AppConstants.downloadTasksBox),
    Hive.openBox(AppConstants.playbackBox),
  ]);

  final settingsBox = Hive.box(AppConstants.settingsBox);
  final savedCustomUrl = settingsBox.get('customApiUrl', defaultValue: '');
  final savedApiKey = settingsBox.get('apiKey', defaultValue: '');
  
  MusicApiService.instance.setSource(
    MusicSource.custom,
    customUrl: savedCustomUrl.isNotEmpty ? savedCustomUrl : null,
    apiKey: savedApiKey.isNotEmpty ? savedApiKey : null,
  );
  
  // 恢复上次播放的歌曲（暂停状态）和播放位置
  try {
    final audioService = AudioPlayerService.instance;
    final lastSong = await audioService.restoreCurrentSong();
    if (lastSong != null) {
      await audioService.setPlaylist([lastSong], 0, autoPlay: false).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('setPlaylist timed out, skipping restore');
        },
      );
      final savedPosition = await audioService.restorePosition();
      if (savedPosition != null && savedPosition > Duration.zero) {
        await audioService.seek(savedPosition).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('seek timed out, skipping');
          },
        );
      }
    }
    await audioService.restoreQueue();
  } catch (e) {
    debugPrint('Error restoring playback state: $e');
  }
  
  runApp(const MusicApp());
}
