import '../domain/corporation_access.dart';

class AuthorizationAttempt {
  AuthorizationAttempt({
    required this.operationId,
    required this.intendedCharacterId,
    this.status = 'pending',
    this.grantEpoch = 0,
    this.scopes = const {},
    this.quarantined = false,
  });

  final String operationId;
  final int intendedCharacterId;
  String status;
  int grantEpoch;
  Set<String> scopes;
  bool quarantined;
}

/// Naive C2 OAuth coordination: wrong-subject callbacks commit, cancel clears
/// the grant, and reauth overwrites without quarantine.
class CorporationAuthorizationCoordinator {
  CorporationAuthorizationCoordinator();

  final Map<String, AuthorizationAttempt> _attempts = {};
  final Map<int, AuthorizationAttempt> grants = {};

  void start({
    required String operationId,
    required int intendedCharacterId,
    Set<String> scopes = const {},
    int grantEpoch = 0,
  }) {
    _attempts[operationId] = AuthorizationAttempt(
      operationId: operationId,
      intendedCharacterId: intendedCharacterId,
      scopes: scopes,
      grantEpoch: grantEpoch,
    );
    grants[intendedCharacterId] = _attempts[operationId]!;
  }

  GrantTransition completeCallback({
    required String operationId,
    required int callbackCharacterId,
  }) {
    final attempt = _attempts[operationId];
    if (attempt == null) return GrantTransition.unchanged;
    attempt.status = 'committed';
    attempt.grantEpoch += 1;
    grants[callbackCharacterId] = attempt;
    grants[attempt.intendedCharacterId] = attempt;
    return GrantTransition.unchanged;
  }

  GrantTransition cancel(String operationId) {
    final attempt = _attempts[operationId];
    if (attempt == null) return GrantTransition.unchanged;
    attempt.status = 'cancelled';
    grants.remove(attempt.intendedCharacterId);
    return GrantTransition.purged;
  }

  GrantTransition reauthorize({
    required int characterId,
    required Set<String> newScopes,
  }) {
    final existing = grants[characterId];
    if (existing == null) return GrantTransition.unchanged;
    existing.scopes = newScopes;
    existing.grantEpoch += 1;
    existing.quarantined = false;
    return GrantTransition.unchanged;
  }
}
