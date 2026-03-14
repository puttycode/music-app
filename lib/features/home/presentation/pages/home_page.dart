import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/widgets/loading_widget.dart';
import 'package:music_app/core/widgets/error_widget.dart' as app_widgets;
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:music_app/features/home/presentation/widgets/song_card.dart';
import 'package:music_app/features/home/presentation/widgets/section_header.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';

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
                    backgroundColor: AppColors.background,
                    title: Text('音乐', style: AppTextStyles.headlineLarge),
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
                    const SliverToBoxAdapter(
                      child: SectionHeader(title: '为你推荐'),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = state.recommendations[index];
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.albumArt != null
                                  ? Image.network(
                                      song.albumArt!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
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
