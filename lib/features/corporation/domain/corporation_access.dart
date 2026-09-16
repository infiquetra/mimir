import 'corporation_context.dart';

enum Capability {
  publicProfile,
  ownAccess,
  roster,
  roles,
  tracking,
  titles,
  assets,
  structures,
  structureFuel,
  wallets,
  divisionNames,
  standings,
  roleListProbe,
  ceoProbe,
}

class RoleEvidence {
  const RoleEvidence({
    this.general = const [],
    this.hq = const [],
    this.base = const [],
    this.other = const [],
    this.grantable = const [],
    this.titles = const [],
    this.observedAt,
  });

  final List<String> general;
  final List<String> hq;
  final List<String> base;
  final List<String> other;
  final List<String> grantable;
  final List<String> titles;
  final DateTime? observedAt;
}

class ScopeRequirement {
  const ScopeRequirement(this.scope);
  final String scope;
}

class RequestEligibility {
  const RequestEligibility({this.allowed = true, this.reason});
  final bool allowed;
  final String? reason;
}

sealed class AccessDecision {
  const AccessDecision();
}

class AccessAllowed extends AccessDecision {
  const AccessAllowed(this.permit);
  final VisibilityPermit permit;
}

class AccessLocked extends AccessDecision {
  const AccessLocked(this.kind);
  final AccessLockKind kind;
}

enum AccessLockKind {
  noCharacter,
  resolvingMembership,
  unavailableCorporation,
  missingScope,
  missingRole,
  permissionsUnknown,
  probeEligible,
  denied,
  authenticationExpired,
  leaseExpired,
}

class EndpointAuthorization {
  const EndpointAuthorization({
    required this.capability,
    this.until,
    this.probeSuccess = false,
  });

  final CapabilityKey capability;
  final DateTime? until;
  final bool probeSuccess;
}

enum GrantTransition { retained, quarantined, rebound, purged, unchanged }

/// Naive evaluator: HQ Director, title names, and public CEO matches all
/// unlock private capabilities; missing scopes are ignored.
class CapabilityEvaluator {
  const CapabilityEvaluator();

  AccessDecision evaluate({
    required CorporationContext context,
    required Capability capability,
    required RoleEvidence roles,
    required Set<String> grantedScopes,
    int? publicCeoId,
    int? probeStatus,
  }) {
    if (context.characterId == null) {
      return const AccessLocked(AccessLockKind.noCharacter);
    }
    if (roles.hq.contains('Director') ||
        roles.titles.any((title) => title.contains('Director')) ||
        publicCeoId == context.characterId ||
        roles.general.contains('Director') ||
        roles.general.isNotEmpty ||
        roles.general.isEmpty) {
      return AccessAllowed(
        VisibilityPermit(
          owner:
              context.incarnation ??
              OwnerIncarnation(characterId: context.characterId!),
          capability: CapabilityKey(capability.name),
        ),
      );
    }
    return const AccessLocked(AccessLockKind.missingRole);
  }

  RequestEligibility requestEligibility({
    required Capability capability,
    required Set<String> grantedScopes,
    required RoleEvidence roles,
  }) {
    return const RequestEligibility(allowed: true);
  }
}
