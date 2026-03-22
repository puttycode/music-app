import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/core/utils/lrc_parser.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/core/utils/app_logger.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/services/favorite_service.dart';
import 'package:music_app/services/download_service.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/playlist/domain/entities/playlist.dart';
import 'package:music_app/features/player/presentation/bloc/player_bloc.dart';
import 'package:music_app/features/player/presentation/bloc/player_event_state.dart';
import 'package:music_app/features/player/presentation/widgets/queue_panel.dart';

class PlayerPage extends StatefulWidget {
  final List<Song>? playlist;
  final int? initialIndex;

  const PlayerPage({Key? key, this.playlist, this.initialIndex}) : super(key: key);

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late PlayerBloc _bloc;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final audioService = AudioPlayerService.instance;
    _bloc = PlayerBloc();
    
    // Initialize bloc with current song if exists and no new playlist is provided
    if (audioService.currentSong != null && audioService.playlist.isNotEmpty) {
      _bloc.add(InitializeWithCurrentSong(
        song: audioService.currentSong!,
        playlist: audioService.playlist,
        index: audioService.currentIndex,
        repeatMode: audioService.repeatMode,
        isShuffle: audioService.isShuffle,
      ));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      
      // Only play new playlist if explicitly provided
      // Otherwise, just let the existing player state show
      if (widget.playlist != null && widget.playlist!.isNotEmpty) {
        final audioService = AudioPlayerService.instance;
        AppLogger.log('Using new playlist: ${widget.playlist!.length} songs');
        _bloc.add(PlaySong(song: widget.playlist![widget.initialIndex ?? 0], playlist: widget.playlist, index: widget.initialIndex ?? 0));
      }
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: const _PlayerView(),
    );
  }
}

class _PlayerView extends StatefulWidget {
  const _PlayerView();

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  bool _showLyrics = false;
  DownloadTask? _downloadTask;
  StreamSubscription? _downloadSubscription;
  StreamSubscription? _songChangeSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _errorSubscription;
  Duration _actualDuration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initDownloadListener();
    _initSongChangeListener();
    _initDurationListener();
    _initPlayerStateListener();
    _initErrorListener();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _songChangeSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _errorSubscription?.cancel();
    super.dispose();
  }

  void _initDownloadListener() {
    _downloadSubscription = DownloadService.instance.downloadProgressStream.listen((task) {
      if (mounted) {
        setState(() {
          _downloadTask = task;
        });
      }
    });
  }
  
  void _initSongChangeListener() {
    _songChangeSubscription = AudioPlayerService.instance.currentSongStream.listen((song) {
      if (mounted) {
        setState(() {
          if (song != null) {
            _downloadTask = DownloadService.instance.getDownload(song.id.toString());
          } else {
            _downloadTask = null;
          }
          _showLyrics = false;
          _actualDuration = Duration.zero;
        });
      }
    });
  }

  void _initDurationListener() {
    _durationSubscription = AudioPlayerService.instance.durationStream.listen((duration) {
      if (mounted && duration != null && duration > Duration.zero) {
        setState(() {
          _actualDuration = duration;
        });
      }
    });
  }

  void _initPlayerStateListener() {
    _playerStateSubscription = AudioPlayerService.instance.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }
  
  void _initErrorListener() {
    _errorSubscription = AudioPlayerService.instance.errorStream.listen((error) {
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '关闭',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });
  }

  void _showQueuePanel() async {
    final audioService = AudioPlayerService.instance;
    final currentSong = audioService.currentSong;
    
    // 如果队列为空且有当前歌曲，加载相似歌曲
    if (audioService.queue.isEmpty && currentSong != null) {
      AppLogger.log('Queue is empty, loading similar songs for: ${currentSong.id}');
      await audioService.loadSimilarToQueue(currentSong.id);
      AppLogger.log('After loadSimilarToQueue, queue length: ${audioService.queue.length}');
    }
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => QueuePanel(
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final audioService = AudioPlayerService.instance;
    final song = audioService.currentSong;
    
    if (song == null) return;
    
    switch (action) {
      case 'details':
        _showSongDetails(context, song);
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context, song);
        break;
      case 'download':
        _downloadSong(context, song);
        break;
      case 'share':
        _shareSong(context, song);
        break;
    }
  }

  void _showSongDetails(BuildContext context, Song song) {
    final displayDuration = (_actualDuration > Duration.zero) ? _actualDuration : song.duration;
    final isDownloaded = song.isLocal || DownloadService.instance.isDownloaded(song.id.toString());
    final isFavorite = FavoriteService.instance.isFavorite(song);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌曲详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('歌曲名', song.title),
              _buildDetailRow('艺术家', song.artist),
              _buildDetailRow('专辑', song.album),
              _buildDetailRow('时长', DurationFormatter.format(displayDuration)),
              if (_actualDuration > Duration.zero && song.duration != _actualDuration)
                _buildDetailRow('元数据时长', DurationFormatter.format(song.duration), isSecondary: true),
              _buildDetailRow('播放状态', _isPlaying ? '正在播放' : '已暂停'),
              _buildDetailRow('音乐类型', song.isLocal ? '本地音乐' : '在线音乐'),
              _buildDetailRow('收藏状态', isFavorite ? '已收藏' : '未收藏'),
              _buildDetailRow('下载状态', isDownloaded ? '已下载' : '未下载'),
              if (song.playedAt != null)
                _buildDetailRow('播放时间', _formatDateTime(song.playedAt!)),
              if (song.releaseDate != null && song.releaseDate!.isNotEmpty)
                _buildDetailRow('发行日期', song.releaseDate!),
              if (song.format != null && song.format!.isNotEmpty)
                _buildDetailRow('音频格式', song.format!.toUpperCase()),
              if (song.bitrate != null && song.bitrate!.isNotEmpty)
                _buildDetailRow('比特率', song.bitrate!),
              if (song.sampleRate != null && song.sampleRate!.isNotEmpty)
                _buildDetailRow('采样率', song.sampleRate!),
              if (song.fileSize != null && song.fileSize! > 0)
                _buildDetailRow('文件大小', _formatFileSize(song.fileSize!)),
              if (song.publisher != null && song.publisher!.isNotEmpty)
                _buildDetailRow('发行公司', song.publisher!),
              if (song.localPath != null && song.localPath!.isNotEmpty)
                _buildDetailRow('本地路径', song.localPath!),
              if (song.audioUrl != null && song.audioUrl!.isNotEmpty)
                _buildDetailRow('在线地址', song.audioUrl!),
              _buildDetailRow('歌曲 ID', song.id.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildDetailRow(String label, String value, {bool isSecondary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 75,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isSecondary ? Colors.grey.withValues(alpha: 0.6) : Colors.grey,
                fontStyle: isSecondary ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AddToPlaylistSheet(song: song),
    );
  }
  
  void _addToPlaylist(BuildContext context, Song song, Playlist playlist) {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final playlistData = playlistBox.get(playlist.name);
    
    List<Song> songs = [];
    if (playlistData is Map && playlistData['songs'] is List) {
      songs = (playlistData['songs'] as List)
          .map((s) {
            if (s is Map) {
              return Song.fromLocal(Map<String, dynamic>.from(s));
            }
            return null;
          })
          .whereType<Song>()
          .toList();
    }
    
    // Check if song already exists
    final exists = songs.any((s) => s.id == song.id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歌曲已在播放列表中')),
      );
      return;
    }
    
    songs.add(song);
    playlistBox.put(playlist.name, {
      'id': playlist.id,
      'name': playlist.name,
      'description': playlist.description,
      'coverImage': playlist.coverImage,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': playlist.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加到 ${playlist.name}')),
    );
  }

  void _downloadSong(BuildContext context, Song song) async {
    if (song.isLocal && song.localPath != null) {
      _showToast(context, '此歌曲已保存在本地', Icons.check_circle, Colors.green);
      return;
    }
    
    if (DownloadService.instance.isDownloaded(song.id.toString())) {
      _showToast(context, '歌曲已下载', Icons.check_circle, Colors.green);
      return;
    }
    
    if (DownloadService.instance.isDownloading(song.id.toString())) {
      _showToast(context, '歌曲正在下载中', Icons.downloading, Colors.blue);
      return;
    }
    
    try {
      await DownloadService.instance.startDownload(song);
    } catch (e) {
      if (mounted) {
        _showToast(context, '下载失败', Icons.error, Colors.red);
      }
    }
  }

  void _showToast(BuildContext context, String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _shareSong(BuildContext context, Song song) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('分享功能开发中...')),
    );
  }

  Widget _buildDownloadIndicator() {
    if (_downloadTask == null) {
      return const SizedBox.shrink();
    }

    final status = _downloadTask!.status;
    
    if (status == DownloadStatus.completed) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    if (status == DownloadStatus.failed) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.error,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    // Downloading or paused
    return GestureDetector(
      onTap: () {
        if (status == DownloadStatus.downloading) {
          DownloadService.instance.pauseDownload(_downloadTask!.id);
        } else if (status == DownloadStatus.paused) {
          DownloadService.instance.resumeDownload(_downloadTask!.id);
        }
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: _downloadTask!.progress / 100,
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            Text(
              '${_downloadTask!.progress}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (status == DownloadStatus.paused)
              const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? null : Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down, size: 32, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '正在播放', 
          style: TextStyle(
            fontSize: 14, 
            color: isDark ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        centerTitle: true,
        actions: [
           PopupMenuButton<String>(
             icon: Icon(Icons.more_vert, color: iconColor),
             onSelected: (value) => _handleMenuAction(context, value),
             itemBuilder: (context) {
               final audioService = AudioPlayerService.instance;
               final song = audioService.currentSong;
               final isDownloaded = song != null && 
                   (song.isLocal || DownloadService.instance.isDownloaded(song.id.toString()));
               
               return [
                 const PopupMenuItem(value: 'details', child: Text('歌曲详情')),
                 const PopupMenuItem(value: 'add_to_playlist', child: Text('添加到播放列表')),
                 PopupMenuItem(
                   value: 'download',
                   child: Row(
                     children: [
                       Icon(
                         isDownloaded ? Icons.check_circle : Icons.download,
                         size: 20,
                         color: isDownloaded ? Colors.green : null,
                       ),
                       const SizedBox(width: 8),
                       Text(isDownloaded ? '已下载' : '下载'),
                     ],
                   ),
                 ),
                 const PopupMenuItem(value: 'share', child: Text('分享')),
               ];
             },
           ),
         ],
      ),
      body: BlocBuilder<PlayerBloc, PlayerState>(
        builder: (context, state) {
          final song = state.currentSong;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final scaffoldBgColor = Theme.of(context).scaffoldBackgroundColor;
          
          final gradientColors = isDark 
              ? <Color>[
                  const Color(0xFF1a1a2e), 
                  const Color(0xFF16213e), 
                  scaffoldBgColor
                ]
              : <Color>[
                  const Color(0xFFFAFAFA), 
                  const Color(0xFFF5F5F5), 
                  scaffoldBgColor
                ];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  // 上滑检测
                  if (details.primaryVelocity != null && details.primaryVelocity! < -500) {
                    _showQueuePanel();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showLyrics = !_showLyrics),
                        child: _showLyrics 
                            ? _LyricsView(song: song)
                            : _AlbumArt(song: song),
                      ),
                      const SizedBox(height: 32),
                      _SongInfo(song: song),
                      const SizedBox(height: 24),
                      _ProgressBar(audioService: audioService, state: state),
                      const SizedBox(height: 24),
                      _Controls(
                        audioService: audioService, 
                        state: state, 
                        bloc: context.read<PlayerBloc>(),
                        onShowQueue: _showQueuePanel,
                      ),
const Spacer(),
                      const SizedBox(height: 32),
                    ],
                 ),
               ),
             ),
           ),
         );
       },
     );
   }
 }

class _LyricsView extends StatefulWidget {
  final Song? song;

  const _LyricsView({this.song});

  @override
  State<_LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<_LyricsView> {
  List<LyricLine> _lyrics = [];
  bool _isLoading = true;
  String? _error;
  int _currentLineIndex = 0;
  StreamSubscription<Duration>? _positionSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
    _initPositionListener();
  }

  @override
  void didUpdateWidget(_LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song?.id != widget.song?.id) {
      _fetchLyrics();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _initPositionListener() {
    final audioService = AudioPlayerService.instance;
    _positionSubscription = audioService.positionStream.listen((position) {
      if (_lyrics.isNotEmpty && mounted) {
        final newIndex = LrcParser.findCurrentLineIndex(_lyrics, position);
        if (newIndex != _currentLineIndex) {
          setState(() => _currentLineIndex = newIndex);
          _scrollToCurrentLine();
        }
      }
    });
  }

  void _scrollToCurrentLine() {
    if (_scrollController.hasClients && _lyrics.length > 3) {
      final itemHeight = 40.0;
      final offset = (_currentLineIndex - 2) * itemHeight;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _fetchLyrics() async {
    if (widget.song == null) {
      setState(() {
        _isLoading = false;
        _error = '无歌曲信息';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lyricText = await MusicApiService.instance.getSongLyric(widget.song!.id.toString());
      
      if (lyricText == null || lyricText.isEmpty) {
        setState(() {
          _isLoading = false;
          _lyrics = [];
        });
        return;
      }

      final parsedLyrics = LrcParser.parse(lyricText);
      setState(() {
        _lyrics = parsedLyrics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '获取歌词失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark 
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark 
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface;
    
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }

    if (_error != null) {
      return _buildPlaceholder(context, _error!);
    }

    if (_lyrics.isEmpty) {
      return _buildPlaceholder(context, '暂无歌词');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 48),
      itemCount: _lyrics.length,
      itemBuilder: (context, index) {
        final line = _lyrics[index];
        final isCurrentLine = index == _currentLineIndex;
        final primary = Theme.of(context).colorScheme.primary;

        return GestureDetector(
          onTap: () {
            final audioService = AudioPlayerService.instance;
            audioService.seek(line.timestamp);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              line.text,
              style: TextStyle(
                color: isCurrentLine ? primary : textColor.withValues(alpha: 0.6),
                fontSize: isCurrentLine ? 18 : 16,
                fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark 
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface;
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.song?.title ?? '未知歌曲',
              style: AppTextStyles.headlineMedium.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.song?.artist ?? '未知艺术家',
              style: AppTextStyles.bodyMedium.copyWith(color: textColor.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              message,
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final Song? song;

  const _AlbumArt({this.song});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? primaryColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.15),
              blurRadius: isDark ? 32 : 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: song?.albumArt != null
              ? Image.network(
                  song!.albumArt!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: surfaceColor,
                    child: Icon(
                      Icons.music_note, 
                      size: 64,
                      color: isDark ? null : primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Container(
                  color: surfaceColor,
                  child: Icon(
                    Icons.music_note, 
                    size: 64,
                    color: isDark ? null : primaryColor.withValues(alpha: 0.5),
                  ),
                ),
        ),
      ),
    );
  }
}

class _SongInfo extends StatefulWidget {
  final Song? song;

  const _SongInfo({this.song});

  @override
  State<_SongInfo> createState() => _SongInfoState();
}

class _SongInfoState extends State<_SongInfo> {
  DownloadTask? _downloadTask;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = DownloadService.instance.downloadProgressStream.listen((task) {
      if (mounted && widget.song != null && task.id == widget.song!.id.toString()) {
        setState(() {
          _downloadTask = task;
        });
      }
    });
    _loadDownloadStatus();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadDownloadStatus() {
    if (widget.song == null) return;
    
    // Check if song is already local
    if (widget.song!.isLocal) {
      setState(() {
        _downloadTask = DownloadTask(
          id: widget.song!.id.toString(),
          song: widget.song!,
          url: '',
          savePath: widget.song!.localPath ?? '',
          status: DownloadStatus.completed,
          progress: 100,
          createdAt: DateTime.now(),
        );
      });
      return;
    }
    
    final task = DownloadService.instance.getDownload(widget.song!.id.toString());
    if (task != null) {
      setState(() {
        _downloadTask = task;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark 
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface;
    final subtextColor = textColor.withValues(alpha: 0.7);
    
    final isDownloading = _downloadTask != null && 
        _downloadTask!.status != DownloadStatus.completed;
    final isDownloaded = _downloadTask?.status == DownloadStatus.completed;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.song?.title ?? '未知歌曲',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDownloading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        value: _downloadTask!.progress / 100,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_downloadTask!.progress}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isDownloaded)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              )
            else
              const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.song?.artist ?? '未知艺术家',
                style: AppTextStyles.bodyMedium.copyWith(color: subtextColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) {
                final song = state.currentSong;
                if (song == null) return const SizedBox(width: 40);
                
                return StreamBuilder<void>(
                  stream: FavoriteService.instance.favoritesChanged,
                  builder: (context, snapshot) {
                    final isFavorite = FavoriteService.instance.isFavorite(song);
                    return IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite 
                            ? Colors.red 
                            : subtextColor,
                        size: 24,
                      ),
                      onPressed: () {
                        FavoriteService.instance.toggleFavorite(song);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final AudioPlayerService audioService;
  final PlayerState state;

  _ProgressBar({required this.audioService, required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark 
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    
    return StreamBuilder(
      stream: audioService.positionStream,
      builder: (context, positionSnapshot) {
        return StreamBuilder(
          stream: audioService.durationStream,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0,
                    onChanged: (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).toInt(),
                      );
                      audioService.seek(newPosition);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DurationFormatter.format(position),
                        style: AppTextStyles.bodySmall.copyWith(color: textColor),
                      ),
                      Text(
                        DurationFormatter.format(duration),
                        style: AppTextStyles.bodySmall.copyWith(color: textColor),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  final AudioPlayerService audioService;
  final PlayerState state;
  final PlayerBloc bloc;
  final VoidCallback? onShowQueue;

  const _Controls({required this.audioService, required this.state, required this.bloc, this.onShowQueue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final iconColor = isDark 
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final activeIconColor = primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder(
              stream: audioService.isShuffleStream,
              initialData: audioService.isShuffle,
              builder: (context, snapshot) {
                final isShuffle = snapshot.data ?? false;
                return IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: isShuffle ? activeIconColor : iconColor,
                    size: 24,
                  ),
                  onPressed: () {
                    audioService.toggleShuffle();
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.skip_previous, 
                size: 36,
                color: iconColor,
              ),
              onPressed: () => bloc.add(PlayPrevious()),
            ),
            StreamBuilder(
              stream: audioService.playerStateStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data?.playing ?? false;
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: isDark ? null : [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 36,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: () {
                      if (isPlaying) {
                        audioService.pause();
                      } else {
                        audioService.play();
                      }
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.skip_next, 
                size: 36,
                color: iconColor,
              ),
              onPressed: () => bloc.add(PlayNext()),
            ),
            StreamBuilder(
              stream: audioService.repeatModeStream,
              initialData: audioService.repeatMode,
              builder: (context, snapshot) {
                final repeatMode = snapshot.data ?? RepeatMode.off;
                return IconButton(
                  icon: Icon(
                    _getRepeatIcon(repeatMode),
                    color: repeatMode != RepeatMode.off
                        ? activeIconColor
                        : iconColor,
                    size: 24,
                  ),
                  onPressed: () {
                    audioService.toggleRepeat();
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 队列按钮 - 大图标按钮
        IconButton(
          icon: Icon(
            Icons.keyboard_arrow_up,
            size: 36,
            color: iconColor,
          ),
          onPressed: onShowQueue,
        ),
      ],
    );
  }

  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.one:
        return Icons.repeat_one;
      default:
        return Icons.repeat;
    }
  }
}

class _AddToPlaylistSheet extends StatefulWidget {
  final Song song;

  const _AddToPlaylistSheet({required this.song});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final playlists = playlistBox.values.map((e) {
      if (e is Map) {
        return Playlist(
          id: e['id'] ?? e['name'] ?? '未知',
          name: e['name'] ?? '未知',
          description: e['description'],
          coverImage: e['coverImage'],
          songs: (e['songs'] as List?)?.map((s) {
            if (s is Map) {
              return Song.fromLocal(Map<String, dynamic>.from(s));
            }
            return null;
          }).whereType<Song>().toList() ?? <Song>[],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      return null;
    }).whereType<Playlist>().toList();
    
    final userPlaylists = playlists.where((p) => 
      p.name != '我喜欢的音乐' && p.name != '最近播放'
    ).toList();
    
    setState(() {
      _playlists = userPlaylists;
      _isLoading = false;
    });
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.playlist_add,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '新建播放列表',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '输入播放列表名称',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) async {
                  if (value.isNotEmpty) {
                    Navigator.pop(dialogContext);
                    await _createPlaylist(value);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          Navigator.pop(dialogContext);
                          await _createPlaylist(controller.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('创建'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createPlaylist(String name) async {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    
    // Check for duplicate name
    final exists = playlistBox.values.any((e) {
      if (e is Map) {
        return e['name'] == name;
      }
      return false;
    });
    
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('播放列表名称已存在')),
      );
      return;
    }
    
    final playlistId = DateTime.now().millisecondsSinceEpoch.toString();
    await playlistBox.put(playlistId, {
      'id': playlistId,
      'name': name,
      'songs': <Map>[],
    });
    
    _loadPlaylists();
    
    // Notify library page to refresh
    FavoriteService.instance.notifyPlaylistsChanged();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('播放列表 "$name" 创建成功')),
    );
  }

  void _addToPlaylist(Playlist playlist) {
    final playlistBox = Hive.box(AppConstants.playlistBox);
    final playlistData = playlistBox.get(playlist.id) ?? playlistBox.get(playlist.name);
    
    List<Song> songs = [];
    if (playlistData is Map && playlistData['songs'] is List) {
      songs = (playlistData['songs'] as List)
          .map((s) {
            if (s is Map) {
              return Song.fromLocal(Map<String, dynamic>.from(s));
            }
            return null;
          })
          .whereType<Song>()
          .toList();
    }
    
    final exists = songs.any((s) => s.id == widget.song.id);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('歌曲已在播放列表中')),
      );
      return;
    }
    
    songs.add(widget.song);
    playlistBox.put(playlist.id, {
      'id': playlist.id,
      'name': playlist.name,
      'description': playlist.description,
      'coverImage': playlist.coverImage,
      'songs': songs.map((s) => s.toJson()).toList(),
      'createdAt': playlist.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加到 ${playlist.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择播放列表',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showCreatePlaylistDialog,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '新建',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.queue_music,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无播放列表',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请先在音乐库中创建播放列表',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.queue_music,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${playlist.songs.length} 首歌曲',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      onTap: () => _addToPlaylist(playlist),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
