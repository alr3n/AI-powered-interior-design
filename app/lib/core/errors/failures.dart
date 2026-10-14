import 'package:supabase_flutter/supabase_flutter.dart';

/// Sealed failure hierarchy. Data layer catches raw exceptions and maps to
/// these; presentation only ever sees a [Failure] with user-safe copy.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Check your connection and try again.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Sign-in failed. Please try again.']);
}

class AiFailure extends Failure {
  const AiFailure([super.message = 'The AI service had a problem. Try again.']);
}

class QuotaFailure extends Failure {
  const QuotaFailure(
      [super.message = 'AI request limit reached. Try again in a bit.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Upload failed. Please retry.']);
}

class DataFailure extends Failure {
  const DataFailure([super.message = 'Could not save your data. Please retry.']);
}

/// Maps anything thrown by the Supabase SDK (Edge Functions, Postgres,
/// Storage, Auth) to a typed, user-safe [Failure].
Failure mapError(Object error) {
  if (error is Failure) return error;

  if (error is FunctionException) {
    final code = _functionErrorCode(error.details);
    switch (error.status) {
      case 401:
        return const AuthFailure('Your session expired. Please sign in again.');
      case 429:
        return const QuotaFailure();
      case 400:
        return code == 'failed-precondition'
            ? const ValidationFailure(
                'Missing scan data — complete the scan first.')
            : const ValidationFailure('That request could not be processed.');
      case 503:
      case 504:
        return const NetworkFailure(
            'The AI service is busy right now. Try again shortly.');
      default:
        return const AiFailure();
    }
  }
  if (error is AuthException) return AuthFailure(error.message);
  if (error is StorageException) return const StorageFailure();
  if (error is PostgrestException) return const DataFailure();

  final msg = error.toString();
  if (msg.contains('SocketException') ||
      msg.contains('ClientException') ||
      msg.contains('TimeoutException') ||
      msg.contains('Failed host lookup') ||
      msg.contains('network')) {
    return const NetworkFailure();
  }
  return const AiFailure();
}

/// Edge Functions reply `{ "error": { "code": ..., "message": ... } }`.
String? _functionErrorCode(Object? details) {
  if (details is Map && details['error'] is Map) {
    return (details['error'] as Map)['code']?.toString();
  }
  return null;
}
