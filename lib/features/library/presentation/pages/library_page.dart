import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:music_app/core/widgets/loading_widget.dart';
import 'package:music_app/core/widgets/error_widget.dart' as app_widgets;
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/library/presentation/bloc/library_bloc.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LibraryBloc()..add(LoadLocalMusic())..add(LoadPlaylists()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('音乐库', style: Theme.of(context).textTheme.headlineMedium),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreatePlaylistDialog(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '本地音乐'),
              Tab(text: '播放列表'),
              Tab(text: '歌手'),
              Tab(text: '专辑'),
            ],
          ),
        ),
        body: BlocBuilder<LibraryBloc, LibraryState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingList();
            }

            if (state.error != null) {
              return app_widgets.EmptyWidget(
                message: state.error!,
                icon: Icons.music_off,
              );
            }

            return TabBarView(
              children: [
                _LocalSongsTab(songs: state.localSongs),
                _PlaylistsTab(playlists: state.playlists),
                _ArtistsTab(artists: state.artists),
                _AlbumsTab(albums: state.albums),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建播放列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '播放列表名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<LibraryBloc>().add(CreatePlaylist(controller.text));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class _LocalSongsTab extends StatelessWidget {
  final List<Song> songs;

  const _LocalSongsTab({required this.songs});

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return app_widgets.EmptyWidget(
        message: '没有找到本地音乐\n请授予存储权限以扫描音乐',
        icon: Icons.music_off,
        action: ElevatedButton(
          onPressed: () async {
            final status = await Permission.storage.request();
            if (status.isGranted) {
              if (context.mounted) {
                context.read<LibraryBloc>().add(LoadLocalMusic());
              }
            }
          },
          child: const Text('授予权限'),
        ),
      );
    }

    return ListView.builder(
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
            onPressed: () => _playSong(context, songs, index),
          ),
          onTap: () => _playSong(context, songs, index),
        );
      },
    );
  }

  void _playSong(BuildContext context, List<Song> playlist, int index) {
    AudioPlayerService.instance.setPlaylist(playlist, index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(playlist: playlist, initialIndex: index),
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final List<Playlist> playlists;

  const _PlaylistsTab({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return app_widgets.EmptyWidget(
        message: '暂无播放列表',
        icon: Icons.queue_music,
      );
    }

    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        
        // Don't allow deleting default playlists
        if (playlist.name == '我喜欢的音乐' || playlist.name == '最近播放') {
          return ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                playlist.name == '我喜欢的音乐' ? Icons.favorite : Icons.history,
              ),
            ),
            title: Text(playlist.name),
            subtitle: Text('${playlist.songs.length} 首歌曲'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          );
        }
        
        return Dismissible(
          key: Key(playlist.name),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            context.read<LibraryBloc>().add(DeletePlaylist(playlist.name));
          },
          child: ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.queue_music),
            ),
            title: Text(playlist.name),
            subtitle: Text('${playlist.songs.length} 首歌曲'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        );
      },
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  final List<String> artists;

  const _ArtistsTab({required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const app_widgets.EmptyWidget(message: '没有找到歌手');
    }

    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: Text(artists[index][0].toUpperCase()),
          ),
          title: Text(artists[index]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        );
      },
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  final List<String> albums;

  const _AlbumsTab({required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const app_widgets.EmptyWidget(message: '没有找到专辑');
    }

    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.album),
          ),
          title: Text(albums[index]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        );
      },
    );
  }
}
