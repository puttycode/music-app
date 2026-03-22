import 'package:flutter/material.dart';
import 'package:music_app/core/widgets/album_art_image.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/core/utils/duration_formatter.dart';

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
    final isRecentPlays = playlistName == '最近播放';
    
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
          : Column(
              children: [
                // Header with song count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    '共 ${songs.length} 首歌曲',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AlbumArtImage(
                            albumArt: song.albumArt,
                            size: 56,
                          ),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isRecentPlays && song.playedAt != null)
                              Text(
                                '播放于 ${_formatPlayedAt(song.playedAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DurationFormatter.format(song.duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.play_circle_filled),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _playSong(context, index),
                            ),
                          ],
                        ),
                        onTap: () => _playSong(context, index),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  String _formatPlayedAt(DateTime playedAt) {
    final now = DateTime.now();
    final diff = now.difference(playedAt);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${playedAt.month}/${playedAt.day}';
    }
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
