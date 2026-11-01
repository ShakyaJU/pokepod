/// Categories of failure the UI knows how to describe honestly.
enum AppErrorKind { network, notFound, parse, cancelled, unknown }

class AppException implements Exception {
  const AppException(this.kind, this.message);

  final AppErrorKind kind;
  final String message;

  bool get isNetwork => kind == AppErrorKind.network;

  @override
  String toString() => message;
}

/// Turns any error into a short, user-facing sentence.
String describeError(Object error) {
  if (error is AppException) {
    switch (error.kind) {
      case AppErrorKind.network:
        return 'Could not reach PokéAPI and nothing is cached for this yet.';
      case AppErrorKind.notFound:
        return 'PokéAPI has no record for this entry.';
      case AppErrorKind.parse:
        return 'PokéAPI returned data this app could not read.';
      case AppErrorKind.cancelled:
        return 'The request was cancelled.';
      case AppErrorKind.unknown:
        return error.message;
    }
  }
  return 'Something unexpected went wrong.';
}
