import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/core/utils/app_logger.dart';

class AlbumDetailPage extends StatefulWidget {
  final Album album;

  const AlbumDetailPage({Key? key, required this.album}) : super(key: key);

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
  Album? _albumDetail;

  @override
  void initState() {
    super.initState();
    _loadAlbumSongs();
  }

  Future<void> _loadAlbumSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Song> songs = [];
      Album? albumDetail;
      
      AppLogger.log('Loading album: ${widget.album.name}');
      
      // Directly search by album name for better performance
      // The new albums API returns song data, not real album IDs
      final searchResults = await MusicApiService.instance.searchSongs(widget.album.name);
      songs = searchResults.where((s) => 
        s.album.toLowerCase().contains(widget.album.name.toLowerCase())
      ).take(20).toList();
      
      // Also search by artist if available
      if (songs.isEmpty && widget.album.artist != null) {
        final artistResults = await MusicApiService.instance.searchSongs(widget.album.artist!);
        songs = artistResults.where((s) => 
          s.artist.toLowerCase().contains(widget.album.artist!.toLowerCase())
        ).take(20).toList();
      }
      
      AppLogger.log('Found ${songs.length} songs for album: ${widget.album.name}');
      
      setState(() {
        _songs = songs;
        _albumDetail = albumDetail ?? widget.album;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log('Error loading album: $e');
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final album = _albumDetail ?? widget.album;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: album.cover != null
                                      ? Image.network(
                                          album.cover!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 48),
                                        )
                                      : const Icon(Icons.album, size: 48),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      album.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (album.artist != null)
                                      Text(
                                        album.artist!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_songs.length} 首歌曲',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_songs.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _playAll(),
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('播放全部'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                      ],
                      const SliverToBoxAdapter(
                        child: Divider(height: 1),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: _songs.isEmpty
                            ? SliverToBoxAdapter(
                                child: Center(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 32),
                                      Icon(
                                        Icons.album,
                                        size: 64,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '暂无曲目',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final song = _songs[index];
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
                                      trailing: Text(
                                        DurationFormatter.format(song.duration),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      onTap: () => _playSong(index),
                                    );
                                  },
                                  childCount: _songs.length,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    AudioPlayerService.instance.setPlaylist(_songs, 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(playlist: _songs, initialIndex: 0),
      ),
    );
  }

  void _playSong(int index) {
    AudioPlayerService.instance.setPlaylist(_songs, index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(playlist: _songs, initialIndex: index),
      ),
    );
  }
}
