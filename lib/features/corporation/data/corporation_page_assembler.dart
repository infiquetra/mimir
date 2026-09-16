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

/// All-page validation, 304 coverage, missing X-Pages, cursor progress.
class CorporationPageAssembler {
  const CorporationPageAssembler();

  AssembleResult assemble(
    List<AssembledPage> pages, {
    DateTime? payloadReceivedAt,
    DateTime? validatedAt,
  }) {
    final mixed = !acceptsMixedGeneration(pages);
    final pageOneOnly304 = pages.length == 1 && pages.first.statusCode == 304;
    final items = <int>[for (final page in pages) ...page.items];
    final missingXPages = pages.any((page) => page.xPages == null);
    final nonempty = items.isNotEmpty;
    final declaredPages = pages
        .map((page) => page.xPages)
        .whereType<int>()
        .fold<int>(0, (max, value) => value > max ? value : max);
    final coverageShort = declaredPages > 0 && pages.length < declaredPages;
    final complete =
        !mixed &&
        !pageOneOnly304 &&
        !coverageShort &&
        !(missingXPages && nonempty);

    final receivedAt = pageOneOnly304
        ? payloadReceivedAt
        : (payloadReceivedAt ?? validatedAt);

    final outcome = mixed || pageOneOnly304 || !complete
        ? RefreshOutcome.incomplete
        : RefreshOutcome.renewed;

    return AssembleResult(
      envelope: SnapshotEnvelope(
        payload: items,
        times: SourceTimes(
          payloadReceivedAt: receivedAt,
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
        complete: complete,
        coverage: HistoryCoverage(complete: complete, rowCount: items.length),
      ),
      outcome: outcome,
    );
  }

  List<int> followCursor(List<List<int>> pages) {
    final result = <int>[];
    final seen = <int>{};
    for (final page in pages) {
      if (page.isEmpty) continue;
      if (page.every(seen.contains)) {
        throw StateError('cursor loop: no decreasing progress');
      }
      for (final id in page) {
        if (seen.add(id)) result.add(id);
      }
    }
    return result;
  }

  bool acceptsMixedGeneration(List<AssembledPage> pages) {
    if (pages.isEmpty) return true;
    final generation = pages.first.generation;
    return pages.every((page) => page.generation == generation);
  }
}
