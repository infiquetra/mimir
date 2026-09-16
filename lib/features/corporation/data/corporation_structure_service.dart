import '../domain/corporation_access.dart';
import '../domain/corporation_structure.dart';

/// Naive C5: structures require Director even for Station Manager.
class CorporationStructureService {
  const CorporationStructureService();

  bool canView({required RoleEvidence roles, bool hasAssetAccess = false}) {
    return roles.isDirector;
  }

  List<CorporationStructure> publish({
    required RoleEvidence roles,
    required List<CorporationStructure> structures,
    bool hasAssetAccess = false,
  }) {
    if (!canView(roles: roles, hasAssetAccess: hasAssetAccess)) {
      return const [];
    }
    return structures;
  }
}
