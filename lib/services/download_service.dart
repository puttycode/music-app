import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/services/music_api_service.dart';

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadTask {
  final String id;
  final Song song;
  final String url;
  final String savePath;
  DownloadStatus status;
  int progress;
  String? errorMessage;
  final DateTime createdAt;
  DateTime? completedAt;

  DownloadTask({
    required this.id,
    required this.song,
    required this.url,
    required this.savePath,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
  });

  Song toLocalSong() {
    return song.copyWith(
      isLocal: true,
      localPath: savePath,
      audioUrl: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'song': song.toJson(),
      'url': url,
      'savePath': savePath,
      'status': status.index,
      'progress': progress,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'],
      song: Song.fromLocal(Map<String, dynamic>.from(json['song'])),
      url: json['url'],
      savePath: json['savePath'],
      status: DownloadStatus.values[json['status']],
      progress: json['progress'],
      errorMessage: json['errorMessage'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }
}

typedef DownloadCompletedCallback = void Function(DownloadTask task);

class DownloadService {
  static DownloadService? _instance;
  static DownloadService get instance => _instance ??= DownloadService._();

  late Dio _dio;
  late Box _downloadBox;
  final Map<String, CancelToken> _cancelTokens = {};
  final _downloadProgressSubject = StreamController<DownloadTask>.broadcast();
  DownloadCompletedCallback? onDownloadCompleted;

  Stream<DownloadTask> get downloadProgressStream => _downloadProgressSubject.stream;

  DownloadService._() {
    _dio = Dio();
    _downloadBox = Hive.box(AppConstants.downloadTasksBox);
    _resumePausedDownloads();
  }

  Future<void> _resumePausedDownloads() async {
    for (final key in _downloadBox.keys) {
      final taskData = _downloadBox.get(key);
      if (taskData is Map) {
        final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
        if (task.status == DownloadStatus.downloading) {
          task.status = DownloadStatus.paused;
          await _updateTask(task);
        }
        if (task.status == DownloadStatus.paused) {
          await resumeDownload(task.id);
        }
      }
    }
  }

  bool isDownloaded(String songId) {
    final taskData = _downloadBox.get(songId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      return task.status == DownloadStatus.completed;
    }
    return false;
  }

  bool isDownloading(String songId) {
    final taskData = _downloadBox.get(songId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      return task.status == DownloadStatus.downloading || 
             task.status == DownloadStatus.pending;
    }
    return false;
  }

  Future<String> startDownload(Song song, {String? customUrl}) async {
    final taskId = song.id.toString();
    
    if (_downloadBox.containsKey(taskId)) {
      final existing = DownloadTask.fromJson(
        Map<String, dynamic>.from(_downloadBox.get(taskId)),
      );
      if (existing.status == DownloadStatus.completed) {
        debugPrint('Song already downloaded: ${song.title}');
        return taskId;
      }
      if (existing.status == DownloadStatus.downloading) {
        debugPrint('Song is already downloading: ${song.title}');
        return taskId;
      }
      if (existing.status == DownloadStatus.paused) {
        await resumeDownload(taskId);
        return taskId;
      }
      if (existing.status == DownloadStatus.failed) {
        // Retry failed download
        await _downloadBox.delete(taskId);
      }
    }

    final settingsBox = Hive.box('settings');
    final downloadPath = settingsBox.get('downloadPath', 
        defaultValue: '/storage/emulated/0/Music');

    final dir = Directory(downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final filename = '${song.artist} - ${song.title}.mp3'
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final savePath = '$downloadPath/$filename';

    var url = customUrl ?? song.audioUrl;
    if (url == null || url.isEmpty) {
      url = await MusicApiService.instance.getSongUrl(song.id.toString());
    }
    if (url == null || url.isEmpty) {
      throw Exception('No audio URL available for download');
    }

    final task = DownloadTask(
      id: taskId,
      song: song,
      url: url,
      savePath: savePath,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
    );

    await _saveTask(task);
    _downloadProgressSubject.add(task);
    _downloadFile(task);
    
    return taskId;
  }

  Future<void> _downloadFile(DownloadTask task) async {
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    try {
      await _dio.download(
        task.url,
        task.savePath,
        onReceiveProgress: (received, total) async {
          if (total <= 0) return;
          final progress = ((received / total) * 100).toInt();
          if (progress != task.progress) {
            task.progress = progress;
            await _updateTask(task);
            _downloadProgressSubject.add(task);
          }
        },
        cancelToken: cancelToken,
      );

      task.status = DownloadStatus.completed;
      task.progress = 100;
      task.completedAt = DateTime.now();
      await _updateTask(task);
      _downloadProgressSubject.add(task);
      _cancelTokens.remove(task.id);
      
      // Notify listeners that download completed
      onDownloadCompleted?.call(task);
      
      debugPrint('Download completed: ${task.song.title}');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        task.status = DownloadStatus.paused;
        await _updateTask(task);
        _downloadProgressSubject.add(task);
      } else {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.message;
        await _updateTask(task);
        _downloadProgressSubject.add(task);
        debugPrint('Download failed: ${e.message}');
      }
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.errorMessage = e.toString();
      await _updateTask(task);
      _downloadProgressSubject.add(task);
      debugPrint('Download failed: $e');
    }
  }

  Future<void> pauseDownload(String taskId) async {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]!.cancel();
      _cancelTokens.remove(taskId);
    }
    
    final taskData = _downloadBox.get(taskId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.paused;
        await _updateTask(task);
        _downloadProgressSubject.add(task);
      }
    }
  }

  Future<void> resumeDownload(String taskId) async {
    final taskData = _downloadBox.get(taskId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      if (task.status == DownloadStatus.paused || 
          task.status == DownloadStatus.pending) {
        task.status = DownloadStatus.downloading;
        await _saveTask(task);
        _downloadFile(task);
      }
    }
  }

  Future<void> cancelDownload(String taskId) async {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]!.cancel();
      _cancelTokens.remove(taskId);
    }
    
    final taskData = _downloadBox.get(taskId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      final file = File(task.savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    
    await _downloadBox.delete(taskId);
  }

  Future<void> deleteDownload(String taskId) async {
    final taskData = _downloadBox.get(taskId);
    if (taskData is Map) {
      final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
      final file = File(task.savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _downloadBox.delete(taskId);
  }

  List<DownloadTask> getAllDownloads() {
    final tasks = <DownloadTask>[];
    for (final key in _downloadBox.keys) {
      final taskData = _downloadBox.get(key);
      if (taskData is Map) {
        tasks.add(DownloadTask.fromJson(Map<String, dynamic>.from(taskData)));
      }
    }
    return tasks;
  }

  List<Song> getDownloadedSongs() {
    final songs = <Song>[];
    for (final key in _downloadBox.keys) {
      final taskData = _downloadBox.get(key);
      if (taskData is Map) {
        final task = DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
        if (task.status == DownloadStatus.completed) {
          songs.add(task.toLocalSong());
        }
      }
    }
    return songs;
  }

  DownloadTask? getDownload(String taskId) {
    final taskData = _downloadBox.get(taskId);
    if (taskData is Map) {
      return DownloadTask.fromJson(Map<String, dynamic>.from(taskData));
    }
    return null;
  }

  Future<void> _saveTask(DownloadTask task) async {
    await _downloadBox.put(task.id, task.toJson());
  }

  Future<void> _updateTask(DownloadTask task) async {
    await _saveTask(task);
  }

  void dispose() {
    _downloadProgressSubject.close();
  }
}
