import '../domain/corporation_access.dart';

class AuthorizationAttempt {
  AuthorizationAttempt({
    required this.operationId,
    required this.intendedCharacterId,
    this.status = 'pending',
    this.grantEpoch = 0,
    Set<String> scopes = const {},
    this.quarantined = false,
  }) : scopes = Set<String>.from(scopes);

  final String operationId;
  final int intendedCharacterId;
  String status;
  int grantEpoch;
  Set<String> scopes;
  bool quarantined;
}

/// OAuth coordination: wrong-subject reject, cancel retains grant,
/// reauth quarantines then rebinds; scope reduction purges.
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
    final attempt = AuthorizationAttempt(
      operationId: operationId,
      intendedCharacterId: intendedCharacterId,
      scopes: scopes,
      grantEpoch: grantEpoch,
    );
    _attempts[operationId] = attempt;
    grants[intendedCharacterId] = attempt;
  }

  GrantTransition completeCallback({
    required String operationId,
    required int callbackCharacterId,
  }) {
    final attempt = _attempts[operationId];
    if (attempt == null) return GrantTransition.unchanged;
    if (callbackCharacterId != attempt.intendedCharacterId) {
      return GrantTransition.unchanged;
    }
    attempt.status = 'committed';
    attempt.grantEpoch += 1;
    grants[attempt.intendedCharacterId] = attempt;
    return GrantTransition.rebound;
  }

  GrantTransition cancel(String operationId) {
    final attempt = _attempts[operationId];
    if (attempt == null) return GrantTransition.unchanged;
    attempt.status = 'cancelled';
    grants[attempt.intendedCharacterId] = attempt;
    return GrantTransition.retained;
  }

  GrantTransition reauthorize({
    required int characterId,
    required Set<String> newScopes,
  }) {
    final existing = grants[characterId];
    if (existing == null) return GrantTransition.unchanged;
    if (existing.quarantined) {
      existing.scopes = Set<String>.from(newScopes);
      existing.quarantined = false;
      return GrantTransition.rebound;
    }
    final lost = existing.scopes.difference(newScopes);
    if (lost.isNotEmpty) {
      existing.scopes = Set<String>.from(newScopes);
      existing.grantEpoch += 1;
      return GrantTransition.purged;
    }
    existing.quarantined = true;
    existing.grantEpoch += 1;
    return GrantTransition.quarantined;
  }
}
