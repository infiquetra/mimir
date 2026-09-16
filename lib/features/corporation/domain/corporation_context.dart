enum MembershipState {
  noCharacter,
  resolving,
  member,
  npc,
  closed,
  departed,
  unresolved,
}

class OwnerIncarnation {
  const OwnerIncarnation({
    required this.characterId,
    this.uuid = 'incarnation-0',
  });

  final int characterId;
  final String uuid;
}

class CharacterGrant {
  const CharacterGrant({
    required this.characterId,
    this.scopes = const [],
    this.epoch = 0,
  });

  final int characterId;
  final List<String> scopes;
  final int epoch;
}

class CapabilityKey {
  const CapabilityKey(this.id);
  final String id;

  static const publicProfile = CapabilityKey('publicProfile');
  static const ownAccess = CapabilityKey('ownAccess');
  static const roster = CapabilityKey('roster');
  static const roles = CapabilityKey('roles');
  static const tracking = CapabilityKey('tracking');
  static const titles = CapabilityKey('titles');
  static const assets = CapabilityKey('assets');
  static const structures = CapabilityKey('structures');
  static const structureFuel = CapabilityKey('structureFuel');
  static const wallets = CapabilityKey('wallets');
  static const divisionNames = CapabilityKey('divisionNames');
  static const standings = CapabilityKey('standings');
  static const roleListProbe = CapabilityKey('roleListProbe');
  static const ceoProbe = CapabilityKey('ceoProbe');

  @override
  bool operator ==(Object other) => other is CapabilityKey && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class PublicationFence {
  const PublicationFence({this.generation = 0, this.invalidation = 0});
  final int generation;
  final int invalidation;
}

class VisibilityPermit {
  const VisibilityPermit({
    required this.owner,
    this.expiresAt,
    this.capability = CapabilityKey.publicProfile,
  });

  final OwnerIncarnation owner;
  final DateTime? expiresAt;
  final CapabilityKey capability;
}

class CorporationContext {
  const CorporationContext({
    this.tenant = 'tranquility',
    this.characterId,
    this.corporationId = 0,
    this.incarnation,
    this.grant,
    this.membership = MembershipState.member,
    this.generation = 0,
  });

  final String tenant;
  final int? characterId;
  final int corporationId;
  final OwnerIncarnation? incarnation;
  final CharacterGrant? grant;
  final MembershipState membership;
  final int generation;

  /// Naive: corporation 0 is treated as a real member context.
  bool get isResolvedMember => characterId != null;
}
