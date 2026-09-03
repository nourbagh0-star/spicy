enum AppFailureType {
  network,
  timeout,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  unauthorized,
  notFound,
  conflict,
  server,
  configuration,
  unknown,
}

/// A safe, UI-facing classification of a technical exception.
///
/// [technicalMessage] is for local diagnostics only. It must never be shown
/// directly to customers because backend messages can expose implementation
/// details and are rarely actionable.
class AppFailure {
  final AppFailureType type;
  final String technicalMessage;

  const AppFailure({required this.type, required this.technicalMessage});
}
