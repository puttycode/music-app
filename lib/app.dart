import 'package:flutter/material.dart';
import '../player/presentation/pages/player_page.dart';
import '../home/presentation/pages/home_page.dart';
import '../search/presentation/pages/search_page.dart';
import '../library/presentation/pages/library_page.dart';
import '../playlist/presentation/pages/playlist_page.dart';
import '../../core/theme/colors.dart';
import '../../services/audio_player_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService.instance;

  final List<Widget> _pages = [
    const HomePage(),
    const SearchPage(),
    const LibraryPage(),
    const PlaylistPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder(
            stream: _audioService.currentSongStream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return const MiniPlayer();
              }
              return const SizedBox.shrink();
            },
          ),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search),
                label: '搜索',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music),
                label: '音乐库',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.queue_music_outlined),
                activeIcon: Icon(Icons.queue_music),
                label: '播放列表',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioService = AudioPlayerService.instance;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerPage()),
        );
      },
      child: Container(
        height: 64,
        color: AppColors.surfaceVariant,
        child: Column(
          children: [
            StreamBuilder(
              stream: audioService.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return LinearProgressIndicator(
                  value: audioService.currentSong != null &&
                          audioService.currentSong!.duration.inMilliseconds > 0
                      ? position.inMilliseconds /
                          audioService.currentSong!.duration.inMilliseconds
                      : 0,
                  backgroundColor: AppColors.secondary.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 2,
                );
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: audioService.currentSong?.albumArt != null
                          ? Image.network(
                              audioService.currentSong!.albumArt!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: AppColors.surface,
                                child: const Icon(Icons.music_note),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: AppColors.surface,
                              child: const Icon(Icons.music_note),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audioService.currentSong?.title ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            audioService.currentSong?.artist ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder(
                      stream: audioService.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 40,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              audioService.pause();
                            } else {
                              audioService.play();
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
