import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/widgets/loading_widget.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:music_app/features/search/presentation/bloc/search_event.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索歌曲、歌手...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchBloc>().add(ClearSearch());
                  },
                ),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  context.read<SearchBloc>().add(SearchSongs(query));
                }
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const LoadingList();
                }

                if (state.error != null) {
                  return Center(child: Text(state.error!));
                }

                if (state.results.isEmpty) {
                  return _buildSuggestions();
                }

                return ListView.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final song = state.results[index];
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
                        '${song.artist} - ${song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (song.duration.inSeconds < 31)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '30秒',
                                style: TextStyle(fontSize: 10, color: AppColors.warning),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.play_circle_filled),
                            color: AppColors.primary,
                            onPressed: () => _playSong(context, state.results, index),
                          ),
                        ],
                      ),
                      onTap: () => _playSong(context, state.results, index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = ['流行', '摇滚', '电子', '嘻哈', '爵士', '古典', 'R&B', '民谣'];
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('热门搜索', style: AppTextStyles.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(s),
                onPressed: () {
                  _searchController.text = s;
                  context.read<SearchBloc>().add(SearchSongs(s));
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('提示', style: AppTextStyles.titleMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '当前使用 Deezer API，仅提供30秒预览。如需完整播放，可部署网易云解灰API后配置使用。',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _playSong(BuildContext context, List<Song> playlist, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(playlist: playlist, initialIndex: index),
      ),
    );
  }
}
