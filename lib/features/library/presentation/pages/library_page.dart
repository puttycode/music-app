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

class LibraryPage extends StatelessWidget {
  const LibraryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = LibraryBloc()..add(LoadLocalMusic())..add(LoadPlaylists());
        // Set callback to refresh playlists when favorite changes
        FavoriteService.instance.onFavoriteChanged = () {
          bloc.add(RefreshPlaylists());
        };
        // Set callback to refresh recent plays when songs are played
        AudioPlayerService.instance.onRecentPlaysChanged = () {
          bloc.add(RefreshPlaylists());
        };
        return bloc;
      },
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
    // Combine local songs with downloading songs
    final allSongs = [...widget.songs];
    final downloadingSongs = _downloadTasks.values
        .where((task) => task.status != DownloadStatus.completed)
        .map((task) => task.song)
        .toList();
    
    final displaySongs = [...allSongs, ...downloadingSongs];
    
    if (displaySongs.isEmpty) {
      return app_widgets.EmptyWidget(
        message: '没有找到本地音乐\n请授予存储权限以扫描音乐',
        icon: Icons.music_off,
        action: ElevatedButton(
          onPressed: () async {
            Map<Permission, PermissionStatus> statuses;
            
            if (Platform.isAndroid) {
              final androidInfo = await DeviceInfoPlugin().androidInfo;
              if (androidInfo.version.sdkInt >= 33) {
                statuses = await [
                  Permission.photos,
                  Permission.videos,
                  Permission.audio,
                ].request();
              } else {
                statuses = await [Permission.storage].request();
              }
            } else {
              statuses = await [Permission.storage].request();
            }
            
            bool granted = statuses.values.any((s) => s.isGranted);
            
            if (granted) {
              if (context.mounted) {
                context.read<LibraryBloc>().add(LoadLocalMusic());
              }
            } else {
              // Permission denied, show dialog to open settings
              if (context.mounted) {
                final shouldOpenSettings = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('需要权限'),
                    content: const Text('需要存储权限才能扫描本地音乐，请在设置中开启权限'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('去设置'),
                      ),
                    ],
                  ),
                );
                
                if (shouldOpenSettings == true) {
                  await openAppSettings();
                }
              }
            }
          },
          child: const Text('授予权限'),
        ),
      );
    }

    return ListView.builder(
      itemCount: displaySongs.length,
      itemBuilder: (context, index) {
        final song = displaySongs[index];
        final downloadTask = _downloadTasks[song.id.toString()];
        final isDownloaded = downloadTask?.status == DownloadStatus.completed;
        final isDownloading = downloadTask != null && 
            downloadTask.status != DownloadStatus.completed;
        
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
                  '已下载',
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
                    IconButton(
                      icon: Icon(
                        downloadTask.status == DownloadStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
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
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        DownloadService.instance.cancelDownload(downloadTask.id);
                        setState(() {
                          _downloadTasks.remove(downloadTask.id);
                        });
                      },
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
    // Refresh playlists to update "最近播放"
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
            onTap: () => _openPlaylist(context, playlist),
          );
        }
        
        return Dismissible(
          key: Key(playlist.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            context.read<LibraryBloc>().add(
              DeletePlaylist(playlistId: playlist.id, legacyName: playlist.name),
            );
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
            onTap: () => _openPlaylist(context, playlist),
            onLongPress: () => _showRenameDialog(context, playlist),
          ),
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
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
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
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
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
      return const app_widgets.EmptyWidget(message: '没有找到专辑');
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
