import 'package:flutter/material.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/core/utils/app_logger.dart';
import 'package:music_app/services/music_api_service.dart';

class QueuePanel extends StatefulWidget {
  final VoidCallback? onClose;

  const QueuePanel({Key? key, this.onClose}) : super(key: key);

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  final AudioPlayerService _audioService = AudioPlayerService.instance;
  List<Song> _queue = [];
  bool _isLoading = false;
  String? _error;
  bool _showDebug = false;

  @override
  void initState() {
    super.initState();
    _queue = List.from(_audioService.queue);
    
    // 监听队列变化
    _audioService.queueStream.listen((newQueue) {
      if (mounted) {
        setState(() {
          _queue = List.from(newQueue);
        });
      }
    });
    
    // 监听加载状态
    _audioService.isQueueLoadingStream.listen((loading) {
      if (mounted) {
        setState(() {
          _isLoading = loading;
        });
      }
    });
    
    // 如果队列为空且有当前歌曲，自动加载相似歌曲
    if (_queue.isEmpty) {
      final currentSong = _audioService.currentSong;
      if (currentSong != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadSimilarSongs(currentSong);
        });
      }
    }
  }
  
  Future<void> _loadSimilarSongs(Song currentSong) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    AppLogger.log('Loading similar songs for: ${currentSong.id}');
    
    try {
      await _audioService.loadSimilarToQueue(currentSong, limit: 14);
      
      setState(() {
        _queue = List.from(_audioService.queue);
        _isLoading = false;
      });
      
      AppLogger.log('Queue updated: ${_queue.length} songs');
    } catch (e) {
      AppLogger.log('Failed to load similar songs: $e');
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final currentSong = _audioService.currentSong;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 拖动条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.queue_music, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '播放队列${_queue.isNotEmpty ? ' · ${_queue.length}首' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 调试开关
                IconButton(
                  icon: Icon(
                    _showDebug ? Icons.bug_report : Icons.bug_report_outlined,
                    size: 20,
                    color: _showDebug ? Theme.of(context).colorScheme.primary : null,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDebug = !_showDebug;
                    });
                  },
                ),
                // 刷新按钮
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: currentSong != null && !_isLoading
                      ? () => _loadSimilarSongs(currentSong)
                      : null,
                ),
                // 关闭按钮
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 调试信息（可选显示）
          if (_showDebug && currentSong != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('调试信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('当前歌曲: ${currentSong.title}', style: const TextStyle(fontSize: 11)),
                  Text('歌曲ID: ${currentSong.id}', style: TextStyle(fontSize: 10, color: Colors.grey.withValues(alpha: 0.7))),
                  Text('队列长度: ${_queue.length}', style: const TextStyle(fontSize: 11)),
                  Text('当前索引: ${_audioService.currentQueueIndex}', style: const TextStyle(fontSize: 11)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('错误: $_error', style: const TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                ],
              ),
            ),
          // 加载中提示
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      '正在加载相似歌曲...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 歌曲列表
          Expanded(
            child: _isLoading
                ? const SizedBox.shrink()
                : _queue.isEmpty
                    ? _buildEmptyState()
                    : _buildQueueList(currentSong),
          ),
          // 底部信息
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '队列是空的',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击刷新按钮加载相似歌曲',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(Song? currentSong) {
    final currentQueueIndex = _audioService.currentQueueIndex;
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _queue.length,
      itemBuilder: (context, index) {
        final song = _queue[index];
        final isPlaying = index == currentQueueIndex && 
                         currentSong?.id == song.id;
        
        return Dismissible(
          key: Key('queue_${song.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            setState(() {
              _queue.removeAt(index);
              _audioService.removeFromQueue(index);
            });
          },
          child: InkWell(
            onTap: () {
              _audioService.playFromQueue(index);
            },
            child: Container(
              color: isPlaying 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // 序号或播放图标
                    SizedBox(
                      width: 28,
                      child: isPlaying
                          ? Icon(
                              Icons.play_arrow,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.withValues(alpha: 0.7),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // 封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: song.albumArt != null
                          ? Image.network(
                              song.albumArt!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultCover(),
                            )
                          : _buildDefaultCover(),
                    ),
                    const SizedBox(width: 12),
                    // 歌曲信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                              color: isPlaying 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 时长
                    Text(
                      DurationFormatter.format(song.duration),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 拖动图标
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Icon(Icons.music_note, size: 24),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_queue.length}首歌曲',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          // 队列循环开关
          StreamBuilder<bool>(
            stream: _audioService.isQueueLoopStream,
            initialData: _audioService.isQueueLoop,
            builder: (context, snapshot) {
              final isQueueLoop = snapshot.data ?? false;
              return Row(
                children: [
                  Text(
                    '队列循环',
                    style: TextStyle(
                      fontSize: 14,
                      color: isQueueLoop 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isQueueLoop,
                    onChanged: (value) {
                      _audioService.toggleQueueLoop();
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}