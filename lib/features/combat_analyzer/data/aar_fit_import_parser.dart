import '../../fitting/domain/format_parser.dart';
import '../../fitting/domain/models.dart';
import '../../../core/sde/sde_service.dart';

/// Shared-parser factory used by AAR import. GREEN supplies the exact-name
/// resolver and `rethrowFailures`; the default constructs today's parser.
typedef AarSharedParserFactory =
    FittingFormatParser Function({
      required SdeService sdeService,
      Future<int?> Function(String name)? resolveTypeIdByName,
      bool rethrowFailures,
    });

enum AarFitImportFailureCode {
  malformedFit,
  unresolvedEntries,
  unsupportedLoadedAmmunition,
  localDataUnavailable,
}

final class AarFitImportException extends FormatException {
  AarFitImportException(
    super.message, {
    required this.code,
    this.sourceLines = const [],
  });

  final AarFitImportFailureCode code;
  final List<int> sourceLines;
}

/// AAR import adapter. Current body preserves today's colon-heuristic
/// dispatch so U1 tests compile and fail on the live defects.
final class AarFitImportParser {
  AarFitImportParser({required this.sdeService, this.parserFactory});

  final SdeService sdeService;
  final AarSharedParserFactory? parserFactory;

  Future<Fitting> parse(String rawFit) async {
    final parser =
        parserFactory?.call(
          sdeService: sdeService,
          resolveTypeIdByName: null,
          rethrowFailures: false,
        ) ??
        FittingFormatParser(sdeService);
    final trimmed = rawFit.trim();
    final fitting = trimmed.contains(':')
        ? await parser.parseDna(trimmed)
        : await parser.parseEft(rawFit);
    if (fitting == null || fitting.shipTypeId <= 0) {
      throw const FormatException(
        'Unable to resolve the pasted fit. Paste an EFT fit with a known ship and modules.',
      );
    }
    return fitting;
  }
}
