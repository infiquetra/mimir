import '../domain/corporation_access.dart';
import '../domain/corporation_context.dart';

class CapabilityLease {
  const CapabilityLease({
    required this.capability,
    required this.until,
    this.denied = false,
    this.hidden = false,
  });

  final Capability capability;
  final DateTime until;
  final bool denied;
  final bool hidden;
}

/// 1h access leases. Equality locks. 403 hides cache. Corp 0 never requests.
class CorporationAuthorizationRepository {
  CorporationAuthorizationRepository({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  static const leaseTtl = Duration(hours: 1);

  final DateTime Function() _now;
  final Map<String, CapabilityLease> _leases = {};
  final List<String> issuedRequests = [];

  String _key(int characterId, Capability capability) =>
      '$characterId/${capability.name}';

  void recordSuccess({
    required int characterId,
    required Capability capability,
    required DateTime validatedAt,
  }) {
    _leases[_key(characterId, capability)] = CapabilityLease(
      capability: capability,
      until: validatedAt.add(leaseTtl),
    );
  }

  void recordDenial({
    required int characterId,
    required Capability capability,
  }) {
    final existing = _leases[_key(characterId, capability)];
    _leases[_key(characterId, capability)] = CapabilityLease(
      capability: capability,
      until: existing?.until ?? _now(),
      denied: true,
      hidden: true,
    );
  }

  bool isVisible({required int characterId, required Capability capability}) {
    final lease = _leases[_key(characterId, capability)];
    if (lease == null || lease.denied || lease.hidden) return false;
    return _now().isBefore(lease.until);
  }

  bool mayRequest({
    required CorporationContext context,
    required Capability capability,
  }) {
    if (context.characterId == null || context.corporationId == 0) {
      return false;
    }
    issuedRequests.add('${context.corporationId}/$capability');
    return true;
  }

  bool mayRefreshSelfRoles({required bool hasCorporatePermit}) {
    return true;
  }

  bool cacheReadRenewsLease() => false;
}
