import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';

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
      
      // Try API first if album has a valid numeric ID
      final albumId = widget.album.id;
      if (albumId.isNotEmpty && !albumId.startsWith('album_')) {
        try {
          songs = await MusicApiService.instance.getAlbumTracks(albumId);
        } catch (e) {
          // API failed, fall back to local
        }
      }
      
      // If no songs from API, try local songs
      if (songs.isEmpty) {
        final recentBox = Hive.box(AppConstants.recentPlaysBox);
        final recentSongs = recentBox.values.map((e) {
          if (e is Map) {
            return Song.fromLocal(Map<String, dynamic>.from(e));
          }
          return null;
        }).whereType<Song>().toList();
        
        songs = recentSongs.where((s) => s.album == widget.album.name).toList();
        
        // Also search API for this album name
        if (songs.isEmpty) {
          final apiSongs = await MusicApiService.instance.searchSongs(widget.album.name);
          songs = apiSongs.where((s) => s.album.contains(widget.album.name)).toList();
        }
      }
      
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.name),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: CustomScrollView(
                    slivers: [
                      // Album header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: widget.album.cover != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          widget.album.cover!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 64),
                                        ),
                                      )
                                    : const Icon(Icons.album, size: 64),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.album.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    if (widget.album.artist != null)
                                      Text(
                                        '歌手：${widget.album.artist}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Divider(height: 1),
                      ),
                      // Song list
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
                                      trailing: IconButton(
                                        icon: const Icon(Icons.play_circle_filled),
                                        color: Theme.of(context).colorScheme.primary,
                                        onPressed: () => _playSong(index),
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
