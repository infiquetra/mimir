import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_service.dart';
import '../domain/exploration_reference.dart';
import '../domain/exploration_reference_deriver.dart';

class ExplorationReferenceBundle {
  const ExplorationReferenceBundle({
    required this.manifest,
    this.types = const [],
    this.systems = const [],
    this.checksum = '',
    this.corrupt = false,
  });

  final ReferenceManifest manifest;
  final List<RawWormholeRecord> types;
  final List<SystemReference> systems;
  final String checksum;
  final bool corrupt;
}

class ExplorationImportResult {
  const ExplorationImportResult({
    required this.success,
    this.stampedVersion,
    this.retainedPrevious = false,
    this.error,
  });

  final bool success;
  final int? stampedVersion;
  final bool retainedPrevious;
  final String? error;
}

/// Naive X1 repository: stamps version before validation, replaces newer
/// slices with older ones, and drops unpublished types.
class ExplorationReferenceRepository {
  ExplorationReferenceRepository({
    required this.database,
    required this.service,
  });

  final SdeDatabase database;
  final SdeService service;
  final _deriver = const ReferenceDeriver();

  ReferenceManifest? _manifest;
  List<WormholeTypeReference> _types = const [];

  Future<ReferenceManifest?> readExplorationManifest() async => _manifest;

  Future<List<WormholeTypeReference>> loadWormholeTypes() async => _types;

  Future<String> getSolarSystemName(int solarSystemId) {
    return service.getSolarSystemName(solarSystemId);
  }

  Future<ExplorationImportResult> importBundle(
    ExplorationReferenceBundle bundle,
  ) async {
    _manifest = bundle.manifest;
    if (bundle.corrupt || bundle.manifest.validation == 'invalid') {
      return ExplorationImportResult(
        success: false,
        stampedVersion: bundle.manifest.sdeBuild,
        retainedPrevious: false,
        error: 'invalid',
      );
    }
    _types = _deriver.projectCatalog(bundle.types);
    return ExplorationImportResult(
      success: true,
      stampedVersion: bundle.manifest.sdeBuild,
    );
  }

  Future<ReferenceManifest?> ensureExplorationReference() async {
    return _manifest;
  }
}
