/// Where the server reports what it is doing.
abstract interface class ServerLog {
  void info(String message);

  void error(String message);
}
