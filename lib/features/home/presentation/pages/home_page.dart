import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/widgets/loading_widget.dart';
import 'package:music_app/core/widgets/error_widget.dart' as app_widgets;
import 'package:music_app/core/widgets/album_art_image.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:music_app/features/home/presentation/widgets/song_card.dart';
import 'package:music_app/features/home/presentation/widgets/section_header.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/features/library/presentation/pages/artist_detail_page.dart';
import 'package:music_app/features/library/presentation/pages/album_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(LoadHomeData()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const _LoadingView();
            }

            if (state.error != null) {
              return app_widgets.ErrorWidget(
                message: state.error!,
                onRetry: () => context.read<HomeBloc>().add(LoadHomeData()),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<HomeBloc>().add(LoadHomeData());
              },
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: Text('音乐', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  if (state.recentPlays.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: '最近播放'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.recentPlays.length,
                          itemBuilder: (context, index) {
                            return SongCard(
                              song: state.recentPlays[index],
                              onTap: () => _playSong(context, state.recentPlays, index),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (state.topCharts.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: '热门榜单'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.topCharts.length,
                          itemBuilder: (context, index) {
                            return SongCard(
                              song: state.topCharts[index],
                              onTap: () => _playSong(context, state.topCharts, index),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (state.recommendations.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        title: state.dailyThemeName ?? '为你推荐',
                        subtitle: state.dailyThemeDescription,
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = state.recommendations[index];
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
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.more_vert),
                            onTap: () => _playSong(context, state.recommendations, index),
                          );
                        },
                        childCount: state.recommendations.length,
                      ),
                    ),
                  ],
                  if (state.hotArtists.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: '热门歌手'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.hotArtists.length,
                          itemBuilder: (context, index) {
                            final artist = state.hotArtists[index];
                            return _ArtistCard(
                              artist: artist,
                              onTap: () => _openArtist(context, artist),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  if (state.newAlbums.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: '新专辑'),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: state.newAlbums.length,
                          itemBuilder: (context, index) {
                            final album = state.newAlbums[index];
                            return _AlbumCard(
                              album: album,
                              onTap: () => _openAlbum(context, album),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _playSong(BuildContext context, List<Song> playlist, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(
          playlist: playlist,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openArtist(BuildContext context, Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistDetailPage(artist: artist),
      ),
    );
  }

  void _openAlbum(BuildContext context, Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumDetailPage(album: album),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const LoadingWidget(width: 120, height: 24),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(right: 16),
                child: LoadingWidget(width: 140, height: 180),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const LoadingWidget(width: 120, height: 24),
          const SizedBox(height: 16),
          LoadingList(itemCount: 8),
        ],
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final VoidCallback onTap;

  const _ArtistCard({required this.artist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.surface,
              ),
              child: ClipOval(
                child: artist.avatar != null
                    ? Image.network(
                        artist.avatar!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            if (artist.musicNum != null)
              Text(
                '${artist.musicNum}首',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 140,
                height: 140,
                color: Theme.of(context).colorScheme.surface,
                child: album.cover != null
                    ? Image.network(
                        album.cover!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 48),
                      )
                    : const Icon(Icons.album, size: 48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            if (album.artist != null)
              Text(
                album.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
