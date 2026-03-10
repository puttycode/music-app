import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../services/audio_player_service.dart';
import '../../domain/entities/song.dart';
import '../bloc/player_bloc.dart';

class PlayerPage extends StatelessWidget {
  final List<Song>? playlist;
  final int? initialIndex;

  const PlayerPage({Key? key, this.playlist, this.initialIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = PlayerBloc();
        if (playlist != null) {
          bloc.add(PlaySong(song: playlist![initialIndex ?? 0], playlist: playlist, index: initialIndex ?? 0));
        }
        return bloc;
      },
      child: const _PlayerView(),
    );
  }
}

class _PlayerView extends StatelessWidget {
  const _PlayerView();

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

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.background],
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
                    _AlbumArt(song: song),
                    const SizedBox(height: 32),
                    _SongInfo(song: song),
                    const SizedBox(height: 24),
                    _ProgressBar(audioService: audioService, state: state),
                    const SizedBox(height: 24),
                    _Controls(audioService: audioService, state: state),
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
              color: AppColors.primary.withOpacity(0.3),
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

  const _ProgressBar({required this.audioService, required this.state});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: audioService.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = state.duration;

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
  }
}

class _Controls extends StatelessWidget {
  final AudioPlayerService audioService;
  final PlayerState state;

  const _Controls({required this.audioService, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.shuffle,
            color: state.isShuffle ? AppColors.primary : AppColors.onSurfaceVariant,
          ),
          onPressed: () => audioService.toggleShuffle(),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36),
          onPressed: () => audioService.playPrevious(),
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
                    audioService.p else {
                    audioause();
                  }Service.play();
                  }
                },
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36),
          onPressed: () => audioService.playNext(),
        ),
        IconButton(
          icon: Icon(
            _getRepeatIcon(state.repeatMode),
            color: state.repeatMode != RepeatMode.off
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
          onPressed: () => audioService.toggleRepeat(),
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
