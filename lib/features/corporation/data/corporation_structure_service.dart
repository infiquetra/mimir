import '../domain/corporation_access.dart';
import '../domain/corporation_structure.dart';

class CorporationStructureService {
  const CorporationStructureService();

  bool canView({required RoleEvidence roles, bool hasAssetAccess = false}) {
    return const CorporationStructureView().visibleWithoutAssets(roles);
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
