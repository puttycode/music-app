class ApiConstants {
  static const String deezerBaseUrl = 'https://api.deezer.com';
  static const String deezerChart = '/chart/0/tracks';
  static const String deezerSearch = '/search';
  static const String deezerArtist = '/artist';
  static const String deezerAlbum = '/album';
  static const String deezerPlaylist = '/playlist';
  static const String deezerRecommendations = '/user/me/recommendations';
  
  static String getTrackUrl(int id) => '/track/$id';
  static String getAlbumTracks(int albumId) => '/album/$albumId/tracks';
  static String getArtistTop(int artistId) => '/artist/$artistId/top';
}
