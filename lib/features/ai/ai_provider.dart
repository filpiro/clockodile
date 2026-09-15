/// Where a Note Summary comes from. The UI never knows which one.
abstract interface class AiProvider {
  /// The summary line, trimmed and non-empty. Throws [AiFailure] on anything
  /// else. Completing [cancelled] abandons the attempt: it kills the process or
  /// aborts the HTTP request, and the returned future then throws
  /// [AiCancelled].
  Future<String> summarize(String text, {Future<void>? cancelled});
}

/// Normalized failure. [message] is the Italian text the UI shows as-is.
sealed class AiFailure implements Exception {
  const AiFailure();
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

final class AiTimeout extends AiFailure {
  const AiTimeout();
  @override
  String get message => "L'AI locale non ha risposto in tempo. Riprova.";
}

final class AiInvalidResponse extends AiFailure {
  const AiInvalidResponse();
  @override
  String get message => "Risposta dell'AI non valida. Riprova.";
}

final class AiContextOverflow extends AiFailure {
  const AiContextOverflow();
  @override
  String get message =>
      "Testo troppo lungo per l'AI locale. Accorcialo e riprova.";
}

/// A CLI provider's own diagnostic: its first stderr line.
final class AiCliFailure extends AiFailure {
  const AiCliFailure(this.message);
  @override
  final String message;
}

/// Never shown: the page that asked is gone.
final class AiCancelled extends AiFailure {
  const AiCancelled();
  @override
  String get message => 'Annullato.';
}
