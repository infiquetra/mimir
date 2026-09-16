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

  bool get isDirector => general.contains('Director');
  bool get isPersonnelManager => general.contains('Personnel_Manager');
  bool get isStationManager => general.contains('Station_Manager');
  bool get isAccountant =>
      general.contains('Accountant') || general.contains('Junior_Accountant');
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

/// Pure F1 evaluator. General roles only; HQ/title/public-CEO never elevate.
class CapabilityEvaluator {
  const CapabilityEvaluator();

  static const membershipScope =
      'esi-corporations.read_corporation_membership.v1';
  static const trackingScope = 'esi-corporations.track_members.v1';
  static const titlesScope = 'esi-corporations.read_titles.v1';
  static const divisionsScope = 'esi-corporations.read_divisions.v1';
  static const assetsScope = 'esi-assets.read_corporation_assets.v1';
  static const structuresScope = 'esi-corporations.read_structures.v1';
  static const walletsScope = 'esi-wallet.read_corporation_wallets.v1';

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
    // A public CEO match never unlocks private capabilities.
    final ceoMatch = publicCeoId != null && publicCeoId == context.characterId;
    if (capability == Capability.ceoProbe && ceoMatch) {
      return const AccessLocked(AccessLockKind.probeEligible);
    }
    if (_requiresMember(capability) && !context.isResolvedMember) {
      return AccessLocked(
        context.corporationId == 0
            ? AccessLockKind.resolvingMembership
            : AccessLockKind.unavailableCorporation,
      );
    }

    if (capability == Capability.roleListProbe) {
      if (probeStatus == 403) {
        return const AccessLocked(AccessLockKind.denied);
      }
      if (probeStatus == 200 || probeStatus == 304) {
        return AccessAllowed(_permit(context, capability));
      }
      if (!_hasScopes(capability, grantedScopes)) {
        return const AccessLocked(AccessLockKind.missingScope);
      }
      return const AccessLocked(AccessLockKind.probeEligible);
    }

    if (!_hasScopes(capability, grantedScopes)) {
      return const AccessLocked(AccessLockKind.missingScope);
    }
    if (!_roleAllows(capability, roles)) {
      return const AccessLocked(AccessLockKind.missingRole);
    }
    return AccessAllowed(_permit(context, capability));
  }

  RequestEligibility requestEligibility({
    required Capability capability,
    required Set<String> grantedScopes,
    required RoleEvidence roles,
  }) {
    if (!_hasScopes(capability, grantedScopes)) {
      return const RequestEligibility(allowed: false, reason: 'missingScope');
    }
    if (!_roleAllows(capability, roles)) {
      return const RequestEligibility(allowed: false, reason: 'missingRole');
    }
    return const RequestEligibility(allowed: true);
  }

  bool _hasScopes(Capability capability, Set<String> granted) {
    for (final scope in _scopesFor(capability)) {
      if (!granted.contains(scope)) return false;
    }
    return true;
  }

  List<String> _scopesFor(Capability capability) {
    return switch (capability) {
      Capability.publicProfile ||
      Capability.ownAccess ||
      Capability.ceoProbe => const [],
      Capability.roster ||
      Capability.roles ||
      Capability.roleListProbe => [membershipScope],
      Capability.tracking => [trackingScope],
      Capability.titles => [titlesScope],
      Capability.assets || Capability.structureFuel => [assetsScope],
      Capability.structures => [structuresScope],
      Capability.wallets => [walletsScope, membershipScope],
      Capability.divisionNames => [divisionsScope],
      Capability.standings => const [],
    };
  }

  bool _roleAllows(Capability capability, RoleEvidence roles) {
    return switch (capability) {
      Capability.publicProfile ||
      Capability.ownAccess ||
      Capability.roster ||
      Capability.standings ||
      Capability.ceoProbe ||
      Capability.roleListProbe => true,
      Capability.roles => roles.isDirector || roles.isPersonnelManager,
      Capability.tracking ||
      Capability.titles ||
      Capability.assets ||
      Capability.structureFuel ||
      Capability.divisionNames => roles.isDirector,
      Capability.structures => roles.isDirector || roles.isStationManager,
      Capability.wallets => roles.isDirector || roles.isAccountant,
    };
  }

  bool _requiresMember(Capability capability) {
    return switch (capability) {
      Capability.publicProfile ||
      Capability.ownAccess ||
      Capability.standings ||
      Capability.ceoProbe => false,
      _ => true,
    };
  }

  VisibilityPermit _permit(CorporationContext context, Capability capability) {
    return VisibilityPermit(
      owner:
          context.incarnation ??
          OwnerIncarnation(
            characterId: context.characterId!,
            uuid: 'c${context.characterId}',
          ),
      capability: CapabilityKey(capability.name),
    );
  }
}
