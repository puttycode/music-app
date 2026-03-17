class AppLogger {
  static Function(String)? _logCallback;

  static void setLogger(Function(String) callback) {
    _logCallback = callback;
  }

  static void log(String message) {
    _logCallback?.call(message);
  }
}
