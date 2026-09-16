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

/// Naive C2 auth: equality still allows, 403 leaves cache readable, corp 0
/// still requests, and self-role refresh waits on a corporate permit.
class CorporationAuthorizationRepository {
  CorporationAuthorizationRepository({DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, CapabilityLease> _leases = {};
  final List<String> issuedRequests = [];
  var selfRoleRequiresCorporatePermit = true;

  String _key(int characterId, Capability capability) =>
      '$characterId/${capability.name}';

  void recordSuccess({
    required int characterId,
    required Capability capability,
    required DateTime validatedAt,
  }) {
    _leases[_key(characterId, capability)] = CapabilityLease(
      capability: capability,
      until: validatedAt.add(const Duration(hours: 1)),
    );
  }

  void recordDenial({
    required int characterId,
    required Capability capability,
  }) {
    final existing = _leases[_key(characterId, capability)];
    if (existing != null) {
      _leases[_key(characterId, capability)] = CapabilityLease(
        capability: capability,
        until: existing.until,
        denied: true,
      );
    }
  }

  bool isVisible({required int characterId, required Capability capability}) {
    final lease = _leases[_key(characterId, capability)];
    if (lease == null) return false;
    if (lease.denied) return true;
    return !_now().isAfter(lease.until);
  }

  bool mayRequest({
    required CorporationContext context,
    required Capability capability,
  }) {
    issuedRequests.add('${context.corporationId}/$capability');
    return context.characterId != null;
  }

  bool mayRefreshSelfRoles({required bool hasCorporatePermit}) {
    return !selfRoleRequiresCorporatePermit || hasCorporatePermit;
  }

  bool cacheReadRenewsLease() => true;
}
