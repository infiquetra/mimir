import '../domain/corporation_snapshot.dart';

class AssembledPage {
  const AssembledPage({
    required this.page,
    required this.statusCode,
    this.xPages,
    this.items = const [],
    this.generation = 1,
    this.fromId,
  });

  final int page;
  final int statusCode;
  final int? xPages;
  final List<int> items;
  final int generation;
  final int? fromId;
}

class AssembleResult {
  const AssembleResult({required this.envelope, required this.outcome});

  final SnapshotEnvelope<List<int>> envelope;
  final RefreshOutcome outcome;
}

/// Naive C2 assembler: page-1 304 renews everything, missing X-Pages is
/// complete, mixed generations are accepted, and cursor pages concatenate.
class CorporationPageAssembler {
  const CorporationPageAssembler();

  AssembleResult assemble(
    List<AssembledPage> pages, {
    DateTime? payloadReceivedAt,
    DateTime? validatedAt,
  }) {
    final items = <int>[for (final page in pages) ...page.items];
    final pageOneOnly304 = pages.length == 1 && pages.first.statusCode == 304;
    return AssembleResult(
      envelope: SnapshotEnvelope(
        payload: items,
        times: SourceTimes(
          payloadReceivedAt: validatedAt ?? payloadReceivedAt,
          validatedAt: validatedAt,
        ),
        pages: [
          for (final page in pages)
            PageEvidence(
              page: page.page,
              xPages: page.xPages,
              statusCode: page.statusCode,
            ),
        ],
        complete: true,
        coverage: HistoryCoverage(complete: true, rowCount: items.length),
      ),
      outcome: pageOneOnly304
          ? RefreshOutcome.notModifiedRenewedAll
          : RefreshOutcome.renewed,
    );
  }

  List<int> followCursor(List<List<int>> pages) {
    return [for (final page in pages) ...page];
  }

  bool acceptsMixedGeneration(List<AssembledPage> pages) => true;
}
