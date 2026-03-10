import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
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
      create: (_) => LibraryBloc()..add(LoadLocalMusic()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('音乐库'),
          backgroundColor: AppColors.background,
          bottom: const TabBar(
            tabs: [
              Tab(text: '本地音乐'),
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
              return app_widgets.ErrorWidget(
                message: state.error!,
                onRetry: () => context.read<LibraryBloc>().add(LoadLocalMusic()),
              );
            }

            return TabBarView(
              children: [
                _LocalSongsTab(songs: state.localSongs),
                _ArtistsTab(artists: state.artists),
                _AlbumsTab(albums: state.albums),
              ],
            );
          },
        ),
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
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.music_note),
                    ),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.music_note),
                  ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium,
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_filled),
            color: AppColors.primary,
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
            backgroundColor: AppColors.surfaceVariant,
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
              color: AppColors.surfaceVariant,
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
