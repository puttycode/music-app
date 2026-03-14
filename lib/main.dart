import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/app.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/music_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Hive.initFlutter();
  await Hive.openBox(AppConstants.playlistBox);
  await Hive.openBox(AppConstants.recentPlaysBox);
  await Hive.openBox(AppConstants.settingsBox);

  final settingsBox = Hive.box(AppConstants.settingsBox);
  final savedSource = settingsBox.get('musicSource', defaultValue: 'kuwo');
  final savedCustomUrl = settingsBox.get('customApiUrl', defaultValue: '');
  
  if (savedSource == 'custom' && savedCustomUrl.isNotEmpty) {
    MusicApiService.instance.setSource(MusicSource.custom, customUrl: savedCustomUrl);
  } else {
    MusicApiService.instance.setSource(MusicSource.kuwo);
  }
  
  runApp(const MusicApp());
}
