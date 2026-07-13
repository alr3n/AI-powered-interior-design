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

/// Maps FirebaseFunctions error codes to typed failures.
Failure mapFunctionsError(Object error) {
  final msg = error.toString();
  if (msg.contains('resource-exhausted')) return const QuotaFailure();
  if (msg.contains('unauthenticated')) return const AuthFailure();
  if (msg.contains('failed-precondition')) {
    return const ValidationFailure('Missing scan data — complete the scan first.');
  }
  if (msg.contains('unavailable') || msg.contains('network')) {
    return const NetworkFailure();
  }
  return const AiFailure();
}
