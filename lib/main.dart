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

  MusicApiService.instance;
  
  runApp(const MusicApp());
}
