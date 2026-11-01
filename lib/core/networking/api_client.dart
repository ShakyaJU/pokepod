import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Minimal JSON-over-HTTP contract so repositories can be tested without a
/// network.
abstract class ApiClient {
  Future<Map<String, dynamic>> getJson(String url, {CancelToken? cancelToken});
}

class DioApiClient implements ApiClient {
  DioApiClient({Dio? dio, this.maxAttempts = 3})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 10),
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;
  final int maxAttempts;

  @override
  Future<Map<String, dynamic>> getJson(
    String url, {
    CancelToken? cancelToken,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _dio.get<dynamic>(url, cancelToken: cancelToken);
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data;
        }
        throw const AppException(
          AppErrorKind.parse,
          'Unexpected response shape from PokéAPI.',
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          throw const AppException(
            AppErrorKind.cancelled,
            'Request cancelled.',
          );
        }
        final status = e.response?.statusCode;
        if (status == 404) {
          throw const AppException(AppErrorKind.notFound, 'Not found.');
        }
        final retryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError ||
            (status != null && status >= 500);
        if (retryable && attempt < maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          continue;
        }
        throw AppException(
          AppErrorKind.network,
          'Network request failed (${status ?? e.type.name}).',
        );
      }
    }
  }
}
