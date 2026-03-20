import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:async';
import 'dart:io';
import 'package:music_app/core/widgets/loading_widget.dart';
import 'package:music_app/core/widgets/error_widget.dart' as app_widgets;
import 'package:music_app/services/audio_player_service.dart';
import 'package:music_app/services/favorite_service.dart';
import 'package:music_app/services/download_service.dart';
import 'package:music_app/features/player/domain/entities/song.dart';
import 'package:music_app/features/player/domain/entities/artist.dart';
import 'package:music_app/features/player/domain/entities/album.dart';
import 'package:music_app/features/library/presentation/bloc/library_bloc.dart';
import 'package:music_app/features/player/presentation/pages/player_page.dart';
import 'package:music_app/features/library/presentation/pages/artist_detail_page.dart';
import 'package:music_app/features/library/presentation/pages/album_detail_page.dart';
import 'package:music_app/features/library/presentation/pages/playlist_detail_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryBloc _bloc;
  VoidCallback? _favoriteCallback;
  VoidCallback? _recentPlaysCallback;
  VoidCallback? _playlistsChangedCallback;
  DownloadCompletedCallback? _downloadCompletedCallback;

  @override
  void initState() {
    super.initState();
    _bloc = LibraryBloc()..add(LoadLocalMusic())..add(LoadPlaylists());
    
    _favoriteCallback = () {
      if (mounted) _bloc.add(RefreshPlaylists());
    };
    FavoriteService.instance.onFavoriteChanged = _favoriteCallback;
    
    _recentPlaysCallback = () {
      if (mounted) {
        _bloc.add(RefreshPlaylists());
        _bloc.add(LoadLocalMusic());
      }
    };
    AudioPlayerService.instance.onRecentPlaysChanged = _recentPlaysCallback;
    
    _playlistsChangedCallback = () {
      if (mounted) {
        _bloc.add(LoadPlaylists());
      }
    };
    FavoriteService.instance.onPlaylistsChanged = _playlistsChangedCallback;
    
    _downloadCompletedCallback = (task) {
      if (mounted) {
        _bloc.add(LoadLocalMusic());
      }
    };
    DownloadService.instance.onDownloadCompleted = _downloadCompletedCallback;
  }

  @override
  void dispose() {
    if (FavoriteService.instance.onFavoriteChanged == _favoriteCallback) {
      FavoriteService.instance.onFavoriteChanged = null;
    }
    if (FavoriteService.instance.onPlaylistsChanged == _playlistsChangedCallback) {
      FavoriteService.instance.onPlaylistsChanged = null;
    }
    if (AudioPlayerService.instance.onRecentPlaysChanged == _recentPlaysCallback) {
      AudioPlayerService.instance.onRecentPlaysChanged = null;
    }
    if (DownloadService.instance.onDownloadCompleted == _downloadCompletedCallback) {
      DownloadService.instance.onDownloadCompleted = null;
    }
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
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
          title: Text('音乐库', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreatePlaylistDialog(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '离线音乐'),
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
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<LibraryBloc>(),
        child: BlocListener<LibraryBloc, LibraryState>(
          listener: (listenerContext, state) {
            if (state.playlistCreated) {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('播放列表创建成功')),
              );
              listenerContext.read<LibraryBloc>().add(ClearPlaylistCreatedFlag());
            } else if (state.error == '播放列表名称已存在') {
              Navigator.pop(dialogContext);
              _showErrorDialog(context, '播放列表名称已存在');
            }
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.playlist_add,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '新建播放列表',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '输入播放列表名称',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        context.read<LibraryBloc>().add(CreatePlaylist(value));
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (controller.text.isNotEmpty) {
                              context.read<LibraryBloc>().add(CreatePlaylist(controller.text));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('创建'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 28,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '提示',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('确定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalSongsTab extends StatefulWidget {
  final List<Song> songs;

  const _LocalSongsTab({required this.songs});

  @override
  State<_LocalSongsTab> createState() => _LocalSongsTabState();
}

class _LocalSongsTabState extends State<_LocalSongsTab> {
  final Map<String, DownloadTask> _downloadTasks = {};
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _initDownloadListener();
    _loadDownloadTasks();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _initDownloadListener() {
    _downloadSubscription = DownloadService.instance.downloadProgressStream.listen((task) {
      if (mounted) {
        setState(() {
          _downloadTasks[task.id] = task;
        });
      }
    });
  }

  void _loadDownloadTasks() {
    final tasks = DownloadService.instance.getAllDownloads();
    setState(() {
      _downloadTasks.clear();
      for (final task in tasks) {
        _downloadTasks[task.id] = task;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localSongs = widget.songs;
    
    // Get currently downloading songs (not completed)
    final downloadingSongs = _downloadTasks.values
        .where((task) => task.status != DownloadStatus.completed && 
                        task.status != DownloadStatus.failed)
        .map((task) => task.song)
        .toList();
    
    // Deduplicate by song id, preferring local versions (which include downloaded)
    final songsMap = <int, Song>{};
    for (final song in localSongs) {
      songsMap[song.id] = song;
    }
    for (final song in downloadingSongs) {
      songsMap.putIfAbsent(song.id, () => song);
    }
    final displaySongs = songsMap.values.toList();
    
    // Sort by title
    displaySongs.sort((a, b) => a.title.compareTo(b.title));
    
    // Show empty state if there are no local songs AND no downloading songs
    if (localSongs.isEmpty && downloadingSongs.isEmpty) {
      return app_widgets.EmptyWidget(
        message: '暂无离线音乐\n下载的歌曲将显示在这里',
        icon: Icons.music_off,
      );
    }

return ListView.builder(
      itemCount: displaySongs.length,
      itemBuilder: (context, index) {
        final song = displaySongs[index];
        final downloadTask = _downloadTasks[song.id.toString()];
        final isDownloaded = song.isLocal || downloadTask?.status == DownloadStatus.completed;
        final isDownloading = downloadTask != null && 
            downloadTask.status != DownloadStatus.completed &&
            downloadTask.status != DownloadStatus.failed;
        
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isDownloading
                ? SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          color: Theme.of(context).colorScheme.surface,
                          child: const Icon(Icons.music_note),
                        ),
                        CircularProgressIndicator(
                          value: downloadTask.progress / 100,
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : song.albumArt != null
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isDownloading)
                Text(
                  '下载中 ${downloadTask.progress}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else if (isDownloaded)
                Text(
                  '本地音乐',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          trailing: isDownloading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: downloadTask.progress / 100,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${downloadTask.progress}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        downloadTask.status == DownloadStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        size: 20,
                      ),
                      onPressed: () {
                        if (downloadTask.status == DownloadStatus.paused) {
                          DownloadService.instance.resumeDownload(downloadTask.id);
                        } else {
                          DownloadService.instance.pauseDownload(downloadTask.id);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () {
                        DownloadService.instance.cancelDownload(downloadTask.id);
                        setState(() {
                          _downloadTasks.remove(downloadTask.id);
                        });
                      },
                    ),
                  ],
                )
              : isDownloaded
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '已下载',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.play_circle_filled),
                          color: Theme.of(context).colorScheme.primary,
                          onPressed: () => _playSong(context, displaySongs, index),
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_circle_filled),
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () => _playSong(context, displaySongs, index),
                    ),
          onTap: isDownloading
              ? null
              : () => _playSong(context, displaySongs, index),
        );
      },
    );
  }

  void _playSong(BuildContext context, List<Song> playlist, int index) {
    AudioPlayerService.instance.setPlaylist(playlist, index);
    context.read<LibraryBloc>().add(RefreshPlaylists());
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
  
  static const _playlistIcons = [
    Icons.music_note,
    Icons.headphones,
    Icons.audiotrack,
    Icons.library_music,
    Icons.album,
    Icons.radio,
    Icons.equalizer,
    Icons.piano,
    Icons.music_note_outlined,
    Icons.queue_music,
  ];
  
  static const _playlistColors = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF00BCD4),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFFF5722),
  ];
  
  int _getIconIndex(String id) {
    return id.hashCode.abs() % _playlistIcons.length;
  }

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
        final iconIndex = _getIconIndex(playlist.id);
        final iconColor = _playlistColors[iconIndex];
        final icon = _playlistIcons[iconIndex];
        
        final isDefault = playlist.name == '我喜欢的音乐' || playlist.name == '最近播放';
        final hasSongs = playlist.songs.isNotEmpty;
        
        Widget listTile = ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: isDefault 
                  ? null 
                  : LinearGradient(
                      colors: [
                        iconColor.withValues(alpha: 0.8),
                        iconColor.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isDefault ? Theme.of(context).colorScheme.surface : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDefault 
                  ? (playlist.name == '我喜欢的音乐' ? Icons.favorite : Icons.history)
                  : icon,
              color: isDefault ? null : Colors.white,
            ),
          ),
          title: Text(
            playlist.name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            '${playlist.songs.length} 首歌曲${hasSongs ? '' : ' · 长按重命名'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          trailing: hasSongs && !isDefault
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right),
                  ],
                )
              : const Icon(Icons.chevron_right),
          onTap: () => _openPlaylist(context, playlist),
          onLongPress: isDefault ? null : () => _showRenameDialog(context, playlist),
        );
        
        // Default playlists or playlists with songs cannot be deleted by swipe
        if (isDefault || hasSongs) {
          return listTile;
        }
        
        return Dismissible(
          key: Key(playlist.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete, color: Colors.white),
                const SizedBox(height: 4),
                const Text(
                  '删除',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            return await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认删除'),
                content: Text('确定要删除播放列表"${playlist.name}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) {
            context.read<LibraryBloc>().add(
              DeletePlaylist(playlistId: playlist.id, legacyName: playlist.name),
            );
          },
          child: listTile,
        );
      },
    );
  }

  void _openPlaylist(BuildContext context, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(
          playlistName: playlist.name,
          songs: playlist.songs,
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Playlist playlist) {
    final controller = TextEditingController(text: playlist.name);
    
    showDialog(
      context: context,
      builder: (dialogContext) => BlocListener<LibraryBloc, LibraryState>(
        listener: (context, state) {
          if (state.error == '播放列表名称已存在') {
            Navigator.pop(dialogContext);
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('提示'),
                content: const Text('播放列表名称已存在'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('确定'),
                  ),
                ],
              ),
            );
          }
        },
        child: AlertDialog(
          title: const Text('重命名播放列表'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '输入新名称',
              labelText: '播放列表名称',
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
                final newName = controller.text.trim();
                if (newName.isNotEmpty && newName != playlist.name) {
                  context.read<LibraryBloc>().add(
                    RenamePlaylist(
                      playlistId: playlist.id,
                      oldName: playlist.name,
                      newName: newName,
                    ),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  final List<Artist> artists;

  const _ArtistsTab({required this.artists});

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const app_widgets.EmptyWidget(message: '没有找到歌手');
    }

    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: artist.avatar != null
                ? NetworkImage(artist.avatar!)
                : null,
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: artist.avatar == null
                ? Text(artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(artist.name),
          subtitle: artist.musicNum != null
              ? Text('${artist.musicNum} 首歌曲')
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ArtistDetailPage(artist: artist),
              ),
            );
          },
        );
      },
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  final List<Album> albums;

  const _AlbumsTab({required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const app_widgets.EmptyWidget(
        message: '没有找到专辑',
        icon: Icons.album,
      );
    }

    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: album.cover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      album.cover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.album),
                    ),
                  )
                : const Icon(Icons.album),
          ),
          title: Text(album.name),
          subtitle: album.artist != null
              ? Text('艺术家: ${album.artist}')
              : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumDetailPage(album: album),
              ),
            );
          },
        );
      },
    );
  }
}
