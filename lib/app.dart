import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/features/home/presentation/pages/home_page.dart';
import 'package:music_app/features/search/presentation/pages/search_page.dart';
import 'package:music_app/features/library/presentation/pages/library_page.dart';
import 'package:music_app/features/playlist/presentation/pages/playlist_page.dart';
import 'package:music_app/features/settings/presentation/pages/settings_page.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/app_theme.dart';
import 'package:music_app/services/audio_player_service.dart';

class MusicApp extends StatefulWidget {
  const MusicApp({Key? key}) : super(key: key);

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  late ThemeMode _themeMode;
  late Box _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    final savedTheme = _settingsBox.get('themeMode', defaultValue: 'dark');
    _themeMode = savedTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
  }

  void _onThemeChanged(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: MainPage(
        currentThemeMode: _themeMode,
        onThemeChanged: _onThemeChanged,
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainPage({
    Key? key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final AudioPlayerService _audioService = AudioPlayerService.instance;

  List<Widget> get _pages => [
    const HomePage(),
    const SearchPage(),
    const LibraryPage(),
    const PlaylistPage(),
    SettingsPage(
      currentThemeMode: widget.currentThemeMode,
      onThemeChanged: widget.onThemeChanged,
    ),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: '设置',
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
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            StreamBuilder(
              stream: audioService.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return StreamBuilder(
                  stream: audioService.currentSongStream,
                  builder: (context, songSnapshot) {
                    final song = songSnapshot.data;
                    final primaryColor = Theme.of(context).colorScheme.primary;
                    return LinearProgressIndicator(
                      value: song != null && song.duration.inMilliseconds > 0
                          ? position.inMilliseconds / song.duration.inMilliseconds
                          : 0,
                      backgroundColor: primaryColor.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(primaryColor),
                      minHeight: 2,
                    );
                  },
                );
              },
            ),
            Expanded(
              child: StreamBuilder(
                stream: audioService.currentSongStream,
                builder: (context, snapshot) {
                  final song = snapshot.data;
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  final surfaceColor = Theme.of(context).colorScheme.surface;
                  final onSurface = Theme.of(context).colorScheme.onSurface;
                  final onSurfaceVariant = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: song?.albumArt != null
                              ? Image.network(
                                  song!.albumArt!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: surfaceColor,
                                    child: const Icon(Icons.music_note),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: surfaceColor,
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
                                song?.title ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song?.artist ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: onSurfaceVariant,
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
                                color: primaryColor,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
