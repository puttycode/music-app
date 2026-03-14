import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<PlayerBloc, PlayerState>(
        builder: (context, state) {
          final song = state.currentSong;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppColors.primaryDark, AppColors.background]
                    : [AppColors.primary, Colors.white],
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
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
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
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.music_note, size: 64),
                  ),
                )
              : Container(
                  color: AppColors.surfaceVariant,
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
                color: isShuffle ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              onPressed: () {
                audioService.toggleShuffle();
                bloc.add(ToggleShuffle());
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: AppColors.onPrimary,
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
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              ),
              onPressed: () {
                audioService.toggleRepeat();
                bloc.add(ToggleRepeat());
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

  _BottomControls({required this.audioService});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.devices),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.favorite_border),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
        ),
      ],
    );
  }
}
