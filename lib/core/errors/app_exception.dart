/// Custom exception hierarchy for the app.
/// Maps network errors, server errors, and cache failures to typed exceptions.
library;

sealed class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, {this.statusCode});

  @override
  String toString() => '$runtimeType: $message';
}

/// No internet connection or DNS failure.
class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection. Please check your network.']);
}

/// Request timed out.
class TimeoutException extends AppException {
  const TimeoutException([super.message = 'Request timed out. Please try again.']);
}

/// Server returned an error status code.
class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

/// Local cache read/write failure.
class CacheException extends AppException {
  const CacheException([super.message = 'Unable to access local data.']);
}

/// Unexpected/unknown error.
class UnknownException extends AppException {
  const UnknownException([super.message = 'An unexpected error occurred.']);
}

/// Invalid or unexpected response format.
class ParseException extends AppException {
  const ParseException([super.message = 'Unable to process the server response.']);
}

/// Image upload failed.
class UploadException extends AppException {
  const UploadException([super.message = 'Failed to upload image. Please try again.']);
}
