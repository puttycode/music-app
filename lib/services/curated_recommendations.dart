import '../features/player/domain/entities/song.dart';
import '../features/player/domain/entities/artist.dart';
import '../features/player/domain/entities/album.dart';
import 'music_api_service.dart';

class CuratedSeed {
  final String query;
  final String genre;
  final String region;

  const CuratedSeed({required this.query, required this.genre, required this.region});
}

class CuratedArtistSeed {
  final String name;
  final String? id;
  final String genre;
  final int weight;

  const CuratedArtistSeed({required this.name, this.id, required this.genre, required this.weight});
}

class CuratedAlbumSeed {
  final String name;
  final String artist;
  final String genre;
  final int weight;

  const CuratedAlbumSeed({required this.name, required this.artist, required this.genre, required this.weight});
}

class CuratedRecommendations {
  static const List<CuratedSeed> _seedQueries = [
    CuratedSeed(query: '流行音乐', genre: 'pop', region: '华语'),
    CuratedSeed(query: '摇滚经典', genre: 'rock', region: '华语'),
    CuratedSeed(query: '爵士蓝调', genre: 'jazz', region: '欧美'),
    CuratedSeed(query: '独立民谣', genre: 'folk', region: '华语'),
    CuratedSeed(query: '电子舞曲', genre: 'edm', region: '欧美'),
    CuratedSeed(query: '古典音乐', genre: 'classical', region: '欧美'),
    CuratedSeed(query: 'RB灵魂乐', genre: 'rnb', region: '欧美'),
    CuratedSeed(query: '华语经典', genre: 'classic_cn', region: '华语'),
    CuratedSeed(query: '日语流行', genre: 'jpop', region: '日语'),
    CuratedSeed(query: '韩流音乐', genre: 'kpop', region: '韩语'),
    CuratedSeed(query: '拉丁音乐', genre: 'latin', region: '欧美'),
    CuratedSeed(query: '嘻哈说唱', genre: 'hiphop', region: '华语'),
    CuratedSeed(query: '轻音乐钢琴', genre: 'piano', region: '欧美'),
    CuratedSeed(query: '新世纪音乐', genre: 'newage', region: '欧美'),
    CuratedSeed(query: '乡村音乐', genre: 'country', region: '欧美'),
    CuratedSeed(query: '华语独立', genre: 'indie_cn', region: '华语'),
    CuratedSeed(query: '另类摇滚', genre: 'altrock', region: '欧美'),
    CuratedSeed(query: '动漫音乐', genre: 'anime', region: '日语'),
    CuratedSeed(query: '雷鬼音乐', genre: 'reggae', region: '欧美'),
    CuratedSeed(query: '蓝调摇滚', genre: 'bluesrock', region: '欧美'),
    CuratedSeed(query: '后摇音乐', genre: 'postrock', region: '欧美'),
    CuratedSeed(query: '心情音乐', genre: 'mood', region: '华语'),
    CuratedSeed(query: '运动音乐', genre: 'workout', region: '欧美'),
    CuratedSeed(query: '夜店舞曲', genre: 'housemusic', region: '欧美'),
    CuratedSeed(query: '氛围音乐', genre: 'ambient', region: '欧美'),
    CuratedSeed(query: '电影原声', genre: 'soundtrack', region: '欧美'),
    CuratedSeed(query: '港台经典', genre: 'hkpop', region: '港台'),
    CuratedSeed(query: '8090后华语', genre: '8090', region: '华语'),
    CuratedSeed(query: '深夜治愈', genre: 'chill', region: '华语'),
    CuratedSeed(query: '车载音乐', genre: 'driving', region: '华语'),
  ];

  static const List<CuratedArtistSeed> _curatedHotArtists = [
    CuratedArtistSeed(name: '周杰伦', genre: '华语流行', weight: 8),
    CuratedArtistSeed(name: 'Taylor Swift', genre: '欧美流行', weight: 9),
    CuratedArtistSeed(name: 'BTS', genre: '韩流Kpop', weight: 9),
    CuratedArtistSeed(name: '陈奕迅', genre: '华语流行', weight: 9),
    CuratedArtistSeed(name: 'Queen', genre: '欧美经典摇滚', weight: 9),
    CuratedArtistSeed(name: '林俊杰', genre: '华语流行', weight: 8),
    CuratedArtistSeed(name: 'Ed Sheeran', genre: '欧美民谣流行', weight: 8),
    CuratedArtistSeed(name: 'Adele', genre: '欧美流行', weight: 8),
    CuratedArtistSeed(name: '王菲', genre: '华语另类', weight: 8),
    CuratedArtistSeed(name: 'Post Malone', genre: '欧美嘻哈流行', weight: 8),
    CuratedArtistSeed(name: 'The Beatles', genre: '欧美经典摇滚', weight: 8),
    CuratedArtistSeed(name: 'Ariana Grande', genre: '欧美流行', weight: 8),
    CuratedArtistSeed(name: '邓紫棋', genre: '华语流行', weight: 8),
    CuratedArtistSeed(name: 'Drake', genre: '欧美嘻哈', weight: 8),
    CuratedArtistSeed(name: 'Coldplay', genre: '欧美另类摇滚', weight: 8),
    CuratedArtistSeed(name: 'Billie Eilish', genre: '欧美另类', weight: 7),
    CuratedArtistSeed(name: '陶喆', genre: '华语RB', weight: 8),
    CuratedArtistSeed(name: 'Linkin Park', genre: '欧美另类摇滚', weight: 8),
    CuratedArtistSeed(name: 'Rihanna', genre: '欧美RB', weight: 8),
    CuratedArtistSeed(name: '王力宏', genre: '华语流行', weight: 8),
    CuratedArtistSeed(name: 'Bruno Mars', genre: '欧美RB流行', weight: 8),
    CuratedArtistSeed(name: '李荣浩', genre: '华语独立', weight: 8),
    CuratedArtistSeed(name: 'Kendrick Lamar', genre: '欧美嘻哈', weight: 9),
    CuratedArtistSeed(name: '五月天', genre: '华语摇滚', weight: 9),
    CuratedArtistSeed(name: 'Justin Bieber', genre: '欧美流行', weight: 7),
    CuratedArtistSeed(name: 'The Weeknd', genre: '欧美RB', weight: 8),
    CuratedArtistSeed(name: '孙燕姿', genre: '华语流行', weight: 7),
    CuratedArtistSeed(name: 'Dua Lipa', genre: '欧美流行舞曲', weight: 8),
    CuratedArtistSeed(name: '蔡依林', genre: '华语流行', weight: 7),
    CuratedArtistSeed(name: '张学友', genre: '华语经典', weight: 8),
    CuratedArtistSeed(name: 'Bad Bunny', genre: '拉丁流行', weight: 8),
    CuratedArtistSeed(name: '梁静茹', genre: '华语流行', weight: 7),
    CuratedArtistSeed(name: 'Michael Jackson', genre: '欧美流行', weight: 9),
    CuratedArtistSeed(name: 'Eason Chan', genre: '华语流行', weight: 9),
    CuratedArtistSeed(name: 'G.E.M.', genre: '华语流行', weight: 7),
    CuratedArtistSeed(name: 'Radiohead', genre: '欧美另类摇滚', weight: 8),
    CuratedArtistSeed(name: '张惠妹', genre: '华语流行', weight: 7),
    CuratedArtistSeed(name: 'BLACKPINK', genre: '韩流Kpop', weight: 8),
  ];

  static const List<CuratedAlbumSeed> _curatedNewAlbums = [
    CuratedAlbumSeed(name: '最伟大的作品', artist: '周杰伦', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '范特西', artist: '周杰伦', genre: '华语流行', weight: 7),
    CuratedAlbumSeed(name: 'Midnights', artist: 'Taylor Swift', genre: '欧美流行', weight: 9),
    CuratedAlbumSeed(name: 'Folklore', artist: 'Taylor Swift', genre: '欧美民谣', weight: 9),
    CuratedAlbumSeed(name: 'To Pimp a Butterfly', artist: 'Kendrick Lamar', genre: '欧美嘻哈', weight: 10),
    CuratedAlbumSeed(name: 'DAMN.', artist: 'Kendrick Lamar', genre: '欧美嘻哈', weight: 9),
    CuratedAlbumSeed(name: 'Good Kid', artist: 'Kendrick Lamar', genre: '欧美嘻哈', weight: 8),
    CuratedAlbumSeed(name: 'The Dark Side of the Moon', artist: 'Pink Floyd', genre: '欧美摇滚', weight: 10),
    CuratedAlbumSeed(name: 'Abbey Road', artist: 'The Beatles', genre: '欧美经典', weight: 10),
    CuratedAlbumSeed(name: 'Sgt. Pepper', artist: 'The Beatles', genre: '欧美经典', weight: 9),
    CuratedAlbumSeed(name: 'In Rainbows', artist: 'Radiohead', genre: '欧美另类', weight: 8),
    CuratedAlbumSeed(name: 'Thriller', artist: 'Michael Jackson', genre: '欧美流行', weight: 10),
    CuratedAlbumSeed(name: 'Bad', artist: 'Michael Jackson', genre: '欧美流行', weight: 9),
    CuratedAlbumSeed(name: 'A Night at the Opera', artist: 'Queen', genre: '欧美摇滚', weight: 9),
    CuratedAlbumSeed(name: 'Kind of Blue', artist: 'Miles Davis', genre: '爵士', weight: 10),
    CuratedAlbumSeed(name: 'Random Access Memories', artist: 'Daft Punk', genre: '电子', weight: 9),
    CuratedAlbumSeed(name: 'Discovery', artist: 'Daft Punk', genre: '电子', weight: 9),
    CuratedAlbumSeed(name: 'Blonde', artist: 'Frank Ocean', genre: '欧美RB', weight: 10),
    CuratedAlbumSeed(name: 'After Hours', artist: 'The Weeknd', genre: '欧美RB', weight: 8),
    CuratedAlbumSeed(name: 'Starboy', artist: 'The Weeknd', genre: '欧美RB', weight: 8),
    CuratedAlbumSeed(name: 'Dawn FM', artist: 'The Weeknd', genre: '欧美RB', weight: 8),
    CuratedAlbumSeed(name: '寓言', artist: '王菲', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '将爱', artist: '王菲', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '十年', artist: '陈奕迅', genre: '华语流行', weight: 9),
    CuratedAlbumSeed(name: 'U87', artist: '陈奕迅', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: 'When We All Fall Asleep', artist: 'Billie Eilish', genre: '欧美另类', weight: 9),
    CuratedAlbumSeed(name: 'Happier Than Ever', artist: 'Billie Eilish', genre: '欧美另类', weight: 8),
    CuratedAlbumSeed(name: '人生公司', artist: '五月天', genre: '华语摇滚', weight: 9),
    CuratedAlbumSeed(name: '自传', artist: '五月天', genre: '华语摇滚', weight: 9),
    CuratedAlbumSeed(name: '第二人生', artist: '五月天', genre: '华语摇滚', weight: 9),
    CuratedAlbumSeed(name: '21', artist: 'Adele', genre: '欧美流行', weight: 9),
    CuratedAlbumSeed(name: '25', artist: 'Adele', genre: '欧美流行', weight: 9),
    CuratedAlbumSeed(name: '等于', artist: '李荣浩', genre: '华语独立', weight: 7),
    CuratedAlbumSeed(name: '耳朵', artist: '李荣浩', genre: '华语独立', weight: 8),
    CuratedAlbumSeed(name: '光年之外', artist: '邓紫棋', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '启示录', artist: '邓紫棋', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: 'UGLY BEAUTY', artist: '蔡依林', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: 'Back to Black', artist: 'Amy Winehouse', genre: '欧美RB', weight: 9),
    CuratedAlbumSeed(name: 'Currents', artist: 'Tame Impala', genre: '欧美迷幻', weight: 8),
    CuratedAlbumSeed(name: 'The Slow Rush', artist: 'Tame Impala', genre: '欧美迷幻', weight: 8),
    CuratedAlbumSeed(name: 'IGOR', artist: 'Tyler, the Creator', genre: '欧美嘻哈', weight: 9),
    CuratedAlbumSeed(name: 'Come Away With Me', artist: 'Norah Jones', genre: '爵士流行', weight: 8),
    CuratedAlbumSeed(name: 'AM', artist: 'Arctic Monkeys', genre: '欧美摇滚', weight: 8),
    CuratedAlbumSeed(name: 'Whatever People Say I Am', artist: 'Arctic Monkeys', genre: '欧美摇滚', weight: 9),
    CuratedAlbumSeed(name: 'Fearless', artist: 'Taylor Swift', genre: '欧美乡村', weight: 8),
    CuratedAlbumSeed(name: 'Evermore', artist: 'Taylor Swift', genre: '欧美民谣', weight: 8),
    CuratedAlbumSeed(name: '她说', artist: '林俊杰', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '学不会', artist: '林俊杰', genre: '华语流行', weight: 8),
    CuratedAlbumSeed(name: '和自己对话', artist: '林俊杰', genre: '华语流行', weight: 7),
    CuratedAlbumSeed(name: 'Bad Guy', artist: 'Billie Eilish', genre: '欧美另类', weight: 8),
    CuratedAlbumSeed(name: '幸存者', artist: '林俊杰', genre: '华语流行', weight: 7),
    CuratedAlbumSeed(name: 'Call Me If You Get Lost', artist: 'Tyler, the Creator', genre: '欧美嘻哈', weight: 8),
  ];

  static final Map<String, dynamic> _sessionCache = {};
  static String _lastCacheDate = '';

  static String _cacheDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static void _clearCacheIfNewDay() {
    final today = _cacheDate();
    if (_lastCacheDate != today) {
      _sessionCache.clear();
      _lastCacheDate = today;
    }
  }

  static int _getDaySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  static List<T> _rotateSeeds<T>(List<T> seeds, int seed) {
    final list = List<T>.from(seeds);
    final count = list.length;
    if (count == 0) return list;
    final startIndex = seed % count;
    return [...list.sublist(startIndex), ...list.sublist(0, startIndex)];
  }

  static List<T> _shuffleWithSeed<T>(List<T> list, int seed) {
    final result = List<T>.from(list);
    for (var i = result.length - 1; i > 0; i--) {
      final j = (seed * (i + 1) * 31) % (i + 1);
      final temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  static List<CuratedArtistSeed> _getDiverseArtists(List<CuratedArtistSeed> artists, int targetCount, int seed) {
    final shuffled = _shuffleWithSeed(artists, seed);
    final genreCount = <String, int>{};
    final regionCount = <String, int>{};
    final result = <CuratedArtistSeed>[];

    for (final artist in shuffled) {
      if (result.length >= targetCount) break;
      
      final genre = artist.genre;
      final region = artist.genre.contains('华语') || artist.genre.contains('港台') 
          ? '华语' 
          : artist.genre.contains('日语') || artist.genre.contains('韩流') 
              ? '日韩' 
              : '欧美';
      
      final genreInResult = genreCount[genre] ?? 0;
      final regionInResult = regionCount[region] ?? 0;
      
      if (genreInResult < (targetCount * 0.4).ceil() && regionInResult < (targetCount * 0.5).ceil()) {
        result.add(artist);
        genreCount[genre] = genreInResult + 1;
        regionCount[region] = regionInResult + 1;
      }
    }
    
    return result;
  }

  static List<CuratedAlbumSeed> _getDiverseAlbums(List<CuratedAlbumSeed> albums, int targetCount, int seed) {
    final shuffled = _shuffleWithSeed(albums, seed);
    final artistCount = <String, int>{};
    final genreCount = <String, int>{};
    final result = <CuratedAlbumSeed>[];

    for (final album in shuffled) {
      if (result.length >= targetCount) break;
      
      final artistInResult = artistCount[album.artist] ?? 0;
      final genreInResult = genreCount[album.genre] ?? 0;
      
      if (artistInResult < 2 && genreInResult < (targetCount * 0.4).ceil()) {
        result.add(album);
        artistCount[album.artist] = artistInResult + 1;
        genreCount[album.genre] = genreInResult + 1;
      }
    }
    
    return result;
  }

  static List<Song> _deduplicateByArtist(List<Song> songs, {int maxPerArtist = 2}) {
    final artistCount = <String, int>{};
    final result = <Song>[];
    for (final song in songs) {
      final artist = song.artist.toLowerCase();
      final count = artistCount.putIfAbsent(artist, () => 0);
      if (count < maxPerArtist) {
        result.add(song);
        artistCount[artist] = count + 1;
      }
    }
    return result;
  }

  static Future<List<Artist>> getDailyHotArtists() async {
    _clearCacheIfNewDay();
    if (_sessionCache.containsKey('hotArtists')) {
      return _sessionCache['hotArtists'] as List<Artist>;
    }

    final seed = _getDaySeed();
    final diverseArtists = _getDiverseArtists(_curatedHotArtists, 15, seed);
    final rotated = _rotateSeeds(diverseArtists, seed);
    final topArtists = rotated.take(10).toList();

    final artists = <Artist>[];
    final seenIds = <String>{};
    for (final s in topArtists) {
      final results = await MusicApiService.instance.searchArtists(s.name);
      if (results.isNotEmpty) {
        final artist = results.first;
        if (!seenIds.contains(artist.id)) {
          artists.add(artist);
          seenIds.add(artist.id);
        }
      }
      if (artists.length >= 10) break;
    }

    if (artists.isEmpty) {
      for (final s in topArtists) {
        artists.add(Artist(id: '', name: s.name, avatar: null, musicNum: null));
        if (artists.length >= 10) break;
      }
    }

    final result = artists.take(10).toList();
    _sessionCache['hotArtists'] = result;
    return result;
  }

  static Future<List<Album>> getDailyNewAlbums() async {
    _clearCacheIfNewDay();
    if (_sessionCache.containsKey('newAlbums')) {
      return _sessionCache['newAlbums'] as List<Album>;
    }

    final seed = _getDaySeed();
    final diverseAlbums = _getDiverseAlbums(_curatedNewAlbums, 15, seed);
    final rotated = _rotateSeeds(diverseAlbums, seed);
    final topAlbums = rotated.take(10).toList();

    final albums = <Album>[];
    final seenIds = <String>{};
    for (final s in topAlbums) {
      final results = await MusicApiService.instance.searchAlbums('${s.name} ${s.artist}');
      if (results.isNotEmpty) {
        final album = results.first;
        if (!seenIds.contains(album.id)) {
          albums.add(album);
          seenIds.add(album.id);
        }
      }
      if (albums.length >= 10) break;
    }

    if (albums.isEmpty) {
      for (final s in topAlbums) {
        albums.add(Album(id: '', name: s.name, artist: s.artist, cover: null));
        if (albums.length >= 10) break;
      }
    }

    final result = albums.take(10).toList();
    _sessionCache['newAlbums'] = result;
    return result;
  }

  static Future<List<Song>> getDailyRecommendations({int targetCount = 10}) async {
    _clearCacheIfNewDay();
    if (_sessionCache.containsKey('recommendations')) {
      return _sessionCache['recommendations'] as List<Song>;
    }

    final seed = _getDaySeed();
    final shuffledSeeds = _shuffleWithSeed(_seedQueries, seed);

    final seenArtistIds = <String>{};
    final result = <Song>[];
    final artistCount = <String, int>{};
    final genreCount = <String, int>{};
    const maxPerArtist = 2;
    const maxPerGenre = 3;

    for (final seedQuery in shuffledSeeds) {
      if (result.length >= targetCount * 2) break;
      if (seenArtistIds.length >= 8) break;

      final songs = await MusicApiService.instance.searchSongs(seedQuery.query);
      final deduped = _deduplicateByArtist(songs, maxPerArtist: maxPerArtist);

      for (final song in deduped) {
        if (result.length >= targetCount) break;

        final artistKey = song.artist.toLowerCase();
        final count = artistCount.putIfAbsent(artistKey, () => 0);
        final genre = seedQuery.genre;
        final genreInResult = genreCount[genre] ?? 0;

        if (count < maxPerArtist && genreInResult < maxPerGenre) {
          result.add(song);
          seenArtistIds.add(artistKey);
          artistCount[artistKey] = count + 1;
          genreCount[genre] = genreInResult + 1;
        }
      }
    }

    final finalResult = result.take(targetCount).toList();
    _sessionCache['recommendations'] = finalResult;
    return finalResult;
  }
}
