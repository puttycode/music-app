import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/services/favorite_service.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/bloc/player_bloc.dart';
import 'package:music_app/features/player/presentation/bloc/player_event_state.dart';

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
    }
  }

  void _showSongDetails(BuildContext context, Song song) {
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
              _buildDetailRow('时长', DurationFormatter.format(song.duration)),
              if (song.localPath != null)
                _buildDetailRow('路径', song.localPath!),
              _buildDetailRow('类型', song.isLocal ? '本地音乐' : '在线音乐'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    // Implementation will be added - shows list of playlists to add to
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到播放列表'),
        content: const Text('此功能开发中...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _downloadSong(BuildContext context, Song song) {
    // Implementation will be added - downloads song to local storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('下载功能开发中...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService.instance;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('正在播放', style: TextStyle(fontSize: 14)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'details', child: Text('歌曲详情')),
              const PopupMenuItem(value: 'add_to_playlist', child: Text('添加到播放列表')),
              const PopupMenuItem(value: 'download', child: Text('下载')),
            ],
          ),
        ],
      ),
      body: BlocBuilder<PlayerBloc, PlayerState>(
        builder: (context, state) {
          final song = state.currentSong;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final primaryColor = Theme.of(context).colorScheme.primary;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppColors.primaryDark, Theme.of(context).scaffoldBackgroundColor]
                    : [Colors.indigo.shade300, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
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
                    _Controls(audioService: audioService, state: state, bloc: context.read<PlayerBloc>()),
                    const Spacer(),
                    _BottomControls(audioService: audioService),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LyricsView extends StatelessWidget {
  final Song? song;

  const _LyricsView({this.song});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  song?.title ?? '未知歌曲',
                  style: AppTextStyles.headlineMedium.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  song?.artist ?? '未知艺术家',
                  style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Text(
                  '暂无歌词',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 32,
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
                    child: const Icon(Icons.music_note, size: 64),
                  ),
                )
              : Container(
                  color: surfaceColor,
                  child: const Icon(Icons.music_note, size: 64),
                ),
        ),
      ),
    );
  }
}

class _SongInfo extends StatelessWidget {
  final Song? song;

  const _SongInfo({this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                song?.title ?? '未知歌曲',
                style: AppTextStyles.headlineMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          song?.artist ?? '未知艺术家',
          style: AppTextStyles.bodyMedium,
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
                        style: AppTextStyles.bodySmall,
                      ),
                      Text(
                        DurationFormatter.format(duration),
                        style: AppTextStyles.bodySmall,
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

  const _Controls({required this.audioService, required this.state, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Row(
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
                color: isShuffle ? primaryColor : onSurfaceVariant,
              ),
              onPressed: () {
                audioService.toggleShuffle();
              },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36),
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
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
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
          icon: const Icon(Icons.skip_next, size: 36),
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
                    ? primaryColor
                    : onSurfaceVariant,
              ),
              onPressed: () {
                audioService.toggleRepeat();
              },
            );
          },
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

class _BottomControls extends StatelessWidget {
  final AudioPlayerService audioService;

  const _BottomControls({required this.audioService});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        final song = state.currentSong;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.devices),
              onPressed: () {},
            ),
            StreamBuilder<void>(
              stream: FavoriteService.instance.favoritesChanged,
              builder: (context, snapshot) {
                final isFavorite = song != null ? FavoriteService.instance.isFavorite(song) : false;
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    if (song != null) {
                      FavoriteService.instance.toggleFavorite(song);
                    }
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {},
            ),
          ],
        );
      },
    );
  }
}
