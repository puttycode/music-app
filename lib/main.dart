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
  await Hive.openBox(AppConstants.downloadTasksBox);

  final settingsBox = Hive.box(AppConstants.settingsBox);
  final savedCustomUrl = settingsBox.get('customApiUrl', defaultValue: '');
  
  // 使用自定义 API（默认或用户配置）
  MusicApiService.instance.setSource(
    MusicSource.custom,
    customUrl: savedCustomUrl.isNotEmpty ? savedCustomUrl : null,
  );
  
  runApp(const MusicApp());
}
