import 'package:flutter/material.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';

class PlaylistDetailPage extends StatelessWidget {
  final String playlistName;
  final List<Song> songs;

  const PlaylistDetailPage({
    Key? key,
    required this.playlistName,
    required this.songs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: songs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_note,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '播放列表为空',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.albumArt != null
                        ? Image.network(
                            song.albumArt!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Theme.of(context).colorScheme.surface,
                              child: const Icon(Icons.music_note),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Theme.of(context).colorScheme.surface,
                            child: const Icon(Icons.music_note),
                          ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_filled),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _playSong(context, index),
                  ),
                  onTap: () => _playSong(context, index),
                );
              },
            ),
    );
  }

  void _playSong(BuildContext context, int index) {
    AudioPlayerService.instance.setPlaylist(songs, index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(playlist: songs, initialIndex: index),
      ),
    );
  }
}
