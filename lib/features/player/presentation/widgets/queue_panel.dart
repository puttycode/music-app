import 'package:flutter/material.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/core/utils/app_logger.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:dio/dio.dart';

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
  List<String> _debugLogs = [];

  @override
  void initState() {
    super.initState();
    _queue = List.from(_audioService.queue);
    _addLog('QueuePanel init: queue length = ${_queue.length}');
    
    // 监听队列变化
    _audioService.queueStream.listen((newQueue) {
      if (mounted) {
        setState(() {
          _queue = List.from(newQueue);
          _isLoading = false;
        });
        _addLog('Queue updated: length = ${_queue.length}');
      }
    });
  }
  
  void _addLog(String message) {
    _debugLogs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    AppLogger.log(message);
  }
  
  Future<void> _loadSimilarWithDebug(String songId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    _addLog('开始加载相似歌曲...');
    _addLog('歌曲ID: $songId');
    
    try {
      // 直接调用API并记录详细信息
      final dio = Dio();
      final apiKey = 'your-secret-api-key';
      final url = 'https://music-api.codeseek.me:37280/api/v1/song/$songId/similar?limit=15';
      
      _addLog('请求URL: $url');
      
      final response = await dio.get(
        url,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      
      _addLog('响应状态: ${response.statusCode}');
      _addLog('响应code: ${response.data['code']}');
      
      if (response.data['code'] == 200) {
        final list = response.data['data']?['list'] as List? ?? [];
        _addLog('返回歌曲数: ${list.length}');
        
        if (list.isNotEmpty) {
          final songs = list.map((item) {
            _addLog('歌曲: ${item['name']} - ${item['artist']}');
            return Song(
              id: item['rid']?.toString() ?? '',
              title: item['name']?.toString() ?? 'Unknown',
              artist: item['artist']?.toString() ?? 'Unknown Artist',
              album: item['album']?.toString() ?? 'Unknown Album',
              albumArt: item['albumArt'],
              duration: Duration(seconds: item['duration'] ?? 0),
              isLocal: false,
            );
          }).toList();
          
          // 过滤掉当前歌曲
          final filteredSongs = songs.where((s) => s.id != songId).toList();
          _addLog('过滤后歌曲数: ${filteredSongs.length}');
          
          // 更新队列
          _audioService.clearQueue();
          for (final song in filteredSongs) {
            _audioService.addToQueue(song);
          }
          
          setState(() {
            _queue = filteredSongs;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = 'API返回空列表';
          });
          _addLog('错误: API返回空列表');
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'API错误: ${response.data['message']}';
        });
        _addLog('API错误: ${response.data['message']}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '异常: $e';
      });
      _addLog('异常: $e');
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
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: currentSong != null 
                      ? () => _loadSimilarWithDebug(currentSong.id)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 调试信息面板
          if (currentSong != null)
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
                  Row(
                    children: [
                      const Text('调试日志', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      if (_debugLogs.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _debugLogs.clear();
                            });
                          },
                          child: const Text('清除', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前歌曲: ${currentSong.title}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    '歌曲ID: ${currentSong.id}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.withValues(alpha: 0.7)),
                  ),
                  Text(
                    '队列长度: ${_queue.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '错误: $_error',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  if (_debugLogs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _debugLogs.join('\n'),
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // 歌曲列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _queue.isEmpty
                ? _buildEmptyState()
                : _buildQueueList(),
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
            '播放歌曲时会自动加载相似推荐',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    final currentSong = _audioService.currentSong;
    
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _queue.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _queue.removeAt(oldIndex);
          _queue.insert(newIndex, item);
          _audioService.reorderQueue(oldIndex, newIndex);
        });
      },
      itemBuilder: (context, index) {
        final song = _queue[index];
        final isPlaying = currentSong?.id == song.id;
        
        return _QueueSongItem(
          key: ValueKey(song.id),
          song: song,
          index: index + 1,
          isPlaying: isPlaying,
          onTap: () {
            _audioService.playFromQueue(index);
          },
          onRemove: () {
            setState(() {
              _queue.removeAt(index);
              _audioService.removeFromQueue(index);
            });
          },
        );
      },
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

class _QueueSongItem extends StatelessWidget {
  final Song song;
  final int index;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const _QueueSongItem({
    Key? key,
    required this.song,
    required this.index,
    this.isPlaying = false,
    this.onTap,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Dismissible(
      key: Key('queue_${song.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        onRemove?.call();
      },
      child: InkWell(
        onTap: onTap,
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
                        '$index',
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
                index: index - 1,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
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
}