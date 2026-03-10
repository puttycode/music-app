import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:music_app/core/theme/colors.dart';
import 'package:music_app/core/theme/text_styles.dart';
import 'package:music_app/core/widgets/error_widget.dart' as app_widgets;
import 'package:music_app/features/playlist/domain/entities/playlist.dart';
import 'package:music_app/features/playlist/presentation/bloc/playlist_bloc.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/services/audio_player_service.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlaylistBloc()..add(LoadPlaylists()),
      child: const _PlaylistView(),
    );
  }
}

class _PlaylistView extends StatelessWidget {
  const _PlaylistView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放列表'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<PlaylistBloc, PlaylistState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.playlists.isEmpty) {
            return app_widgets.EmptyWidget(
              message: '还没有播放列表\n点击 + 创建一个',
              icon: Icons.queue_music,
              action: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('创建播放列表'),
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            );
          }

          return ListView.builder(
            itemCount: state.playlists.length,
            itemBuilder: (context, index) {
              final playlist = state.playlists[index];
              return _PlaylistTile(
                playlist: playlist,
                onTap: () => _openPlaylist(context, playlist),
                onDelete: () => _deletePlaylist(context, playlist.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建播放列表'),
        content: TextField(
          controller: nameController,
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
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<PlaylistBloc>().add(CreatePlaylist(nameController.text));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    if (playlist.songs.isNotEmpty) {
      AudioPlayerService.instance.setPlaylist(playlist.songs, 0);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerPage(playlist: playlist.songs),
        ),
      );
    }
  }

  void _deletePlaylist(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除播放列表'),
        content: const Text('确定要删除这个播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<PlaylistBloc>().add(DeletePlaylist(id));
              Navigator.pop(dialogContext);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: playlist.coverImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(playlist.coverImage!, fit: BoxFit.cover),
              )
            : const Icon(Icons.queue_music, color: AppColors.onSurfaceVariant),
      ),
      title: Text(
        playlist.name,
        style: AppTextStyles.titleMedium,
      ),
      subtitle: Text(
        '${playlist.songs.length} 首歌曲',
        style: AppTextStyles.bodySmall,
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        onSelected: (value) {
          if (value == 'delete') onDelete();
        },
      ),
      onTap: onTap,
    );
  }
}
