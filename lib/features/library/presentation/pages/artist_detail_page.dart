import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
import 'package:music_app/core/utils/duration_formatter.dart';
import 'package:music_app/core/widgets/album_art_image.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/music_api_service.dart';
import 'package:music_app/core/utils/app_logger.dart';

class ArtistDetailPage extends StatefulWidget {
  final Artist artist;

  const ArtistDetailPage({Key? key, required this.artist}) : super(key: key);

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String? _error;
  Artist? _artistDetail;

  @override
  void initState() {
    super.initState();
    _loadArtistSongs();
  }

  Future<void> _loadArtistSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Song> songs = [];
      Artist? artistDetail;
      
      AppLogger.log('Loading artist: ${widget.artist.name}');
      
      // Directly search by artist name for better performance
      // The hot artists API returns song data, not real artist IDs
      final searchResults = await MusicApiService.instance.searchSongs(widget.artist.name);
      songs = searchResults.where((s) => 
        s.artist.toLowerCase().contains(widget.artist.name.toLowerCase())
      ).take(20).toList();
      
      AppLogger.log('Found ${songs.length} songs for artist: ${widget.artist.name}');
      
      setState(() {
        _songs = songs;
        _artistDetail = artistDetail ?? widget.artist;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log('Error loading artist: $e');
      setState(() {
        _error = '加载失败';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = _artistDetail ?? widget.artist;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(artist.name),
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
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                backgroundImage: artist.avatar != null
                                    ? NetworkImage(artist.avatar!)
                                    : null,
                                child: artist.avatar == null
                                    ? Text(
                                        artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 36),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      artist.name,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_songs.length} 首歌曲',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    if (artist.musicNum != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '共 ${artist.musicNum} 首作品',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
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
                                        Icons.music_note,
                                        size: 64,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        '暂无歌曲',
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
                                      subtitle: Text(
                                        song.album,
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
