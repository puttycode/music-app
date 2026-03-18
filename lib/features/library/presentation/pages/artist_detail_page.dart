import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_app/core/constants/app_constants.dart';
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
      
      final artistId = widget.artist.id;
      final isNumericId = RegExp(r'^\d+$').hasMatch(artistId);
      
      if (isNumericId) {
        // Use optimized API - returns artist + songs in one call
        AppLogger.log('Loading artist by ID: $artistId');
        final result = await MusicApiService.instance.getArtistDetailWithSongs(artistId);
        artistDetail = result.$1;
        songs = result.$2;
      }
      
      // If no songs from direct ID, search by artist name
      if (songs.isEmpty) {
        AppLogger.log('Searching artist by name: ${widget.artist.name}');
        
        final artists = await MusicApiService.instance.searchArtists(widget.artist.name);
        Artist? matchedArtist;
        
        for (final a in artists) {
          if (a.name.toLowerCase() == widget.artist.name.toLowerCase()) {
            matchedArtist = a;
            break;
          }
        }
        
        matchedArtist ??= artists.isNotEmpty ? artists.first : null;
        
        if (matchedArtist != null && RegExp(r'^\d+$').hasMatch(matchedArtist.id)) {
          final result = await MusicApiService.instance.getArtistDetailWithSongs(matchedArtist.id);
          artistDetail = result.$1;
          songs = result.$2;
        }
        
        if (songs.isEmpty) {
          final searchResults = await MusicApiService.instance.searchSongs(widget.artist.name);
          songs = searchResults.where((s) => 
            s.artist.toLowerCase().contains(widget.artist.name.toLowerCase())
          ).toList();
        }
      }
      
      // Fallback to local songs
      if (songs.isEmpty) {
        final recentBox = Hive.box(AppConstants.recentPlaysBox);
        final recentSongs = recentBox.values.map((e) {
          if (e is Map) {
            return Song.fromLocal(Map<String, dynamic>.from(e));
          }
          return null;
        }).whereType<Song>().toList();
        
        songs = recentSongs.where((s) => 
          s.artist.toLowerCase() == widget.artist.name.toLowerCase()
        ).toList();
      }
      
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
                                        song.album,
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
