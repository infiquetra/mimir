// X9 RED contracts for SignatureNotebookView (U02–U03, U09, U11–U14, U18).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §6.4–§6.6:
// - raw character/system IDs; writes without a character
// - Import always enabled; clipboard clears input; no §6.6 copy
// - combined Updated time; Eligible without verify; no confirm dialog
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';
import 'package:mimir/features/exploration/presentation/exploration_screen.dart';
import 'package:mimir/features/exploration/presentation/signature_notebook_view.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester,
    SignatureNotebookViewModel model, {
    Size size = const Size(1440, 900),
    double textScale = 1,
    VoidCallback? onSave,
    VoidCallback? onImport,
    VoidCallback? onTrash,
    VoidCallback? onRestore,
    VoidCallback? onDeletePermanent,
    VoidCallback? onVerify,
    VoidCallback? onClose,
    VoidCallback? onSeenAgain,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SignatureNotebookView(
              model: model,
              onSave: onSave,
              onImport: onImport,
              onTrash: onTrash,
              onRestore: onRestore,
              onDeletePermanent: onDeletePermanent,
              onVerify: onVerify,
              onClose: onClose,
              onSeenAgain: onSeenAgain,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  SignatureNotebookViewModel populated({
    bool showImport = false,
    bool showTrash = false,
    bool committing = false,
    bool noCharacter = false,
  }) {
    return SignatureNotebookViewModel(
      characterId: noCharacter ? null : kCharacter7,
      characterName: noCharacter ? null : 'Pilot Seven',
      systemId: kAlphaSystemId,
      systemName: 'Alpha',
      signatures: [F5Fixtures.abcExisting()],
      selected: F5Fixtures.abcExisting(),
      showImport: showImport,
      showTrash: showTrash,
      committing: committing,
      pasteInput: 'keep this scan',
    );
  }

  group('U09 scoped header and writes', () {
    testWidgets(
      'ExplorationScreen Signatures tab hosts SignatureNotebookView',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(size: Size(1440, 900)),
            child: MaterialApp(home: ExplorationScreen()),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Signatures').first);
        await tester.pump();
        expect(find.byType(SignatureNotebookView), findsOneWidget);
      },
    );

    testWidgets('header pins named character and system, never raw IDs', (
      tester,
    ) async {
      await pumpView(tester, populated());
      expect(find.byKey(const Key('notebook-scope-header')), findsOneWidget);
      expect(find.textContaining('Pilot Seven'), findsOneWidget);
      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.textContaining('$kCharacter7'), findsNothing);
      expect(find.textContaining('$kAlphaSystemId'), findsNothing);
      expect(find.textContaining('Item #'), findsNothing);
    });

    testWidgets('no character disables writes only and shows exact copy', (
      tester,
    ) async {
      await pumpView(tester, populated(noCharacter: true));
      expect(
        find.text('Select a character to track signatures.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Add'))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('notebook-scope-header')), findsOneWidget);
    });
  });

  group('U11/U12 scanner import sheet', () {
    testWidgets('clipboard empty and read error preserve input with §6.6 copy', (
      tester,
    ) async {
      await pumpView(
        tester,
        populated(showImport: true).copyWithClipboard(empty: true),
      );
      expect(find.byKey(const Key('scanner-import-sheet')), findsOneWidget);
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pump();
      expect(find.text('keep this scan'), findsOneWidget);
      expect(
        find.text(
          'Clipboard contains no scanner text. Copy rows from EVE or enter text manually.',
        ),
        findsOneWidget,
      );

      await pumpView(
        tester,
        populated(showImport: true).copyWithClipboard(error: true),
      );
      await tester.tap(find.text('Paste from clipboard'));
      await tester.pump();
      expect(find.text('keep this scan'), findsOneWidget);
      expect(
        find.text(
          'Could not read the clipboard. Paste text manually or try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('oversized paste uses exact limit copy', (tester) async {
      await pumpView(
        tester,
        populated(showImport: true).copyWith(pasteTooLarge: true),
      );
      expect(
        find.text(
          'Paste exceeds 5,000 rows or 512 KiB. Split the scan and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('zero valid selection disables Import', (tester) async {
      await pumpView(
        tester,
        populated(showImport: true).copyWith(
          zeroValidSelected: true,
          preview: ImportPreview(
            operationId: 'op-1',
            scope: const NotebookScope(
              characterId: kCharacter7,
              systemId: kAlphaSystemId,
            ),
            observedAt: kExplorationT0,
          ),
        ),
      );
      expect(find.text('No valid signatures selected.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('import-commit')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('revision change during preview keeps input', (tester) async {
      await pumpView(
        tester,
        populated(showImport: true).copyWith(revisionChanged: true),
      );
      expect(
        find.text('Notebook changed. Review the import again.'),
        findsOneWidget,
      );
      expect(find.text('keep this scan'), findsOneWidget);
    });

    testWidgets('commit freezes input and disables cancel', (tester) async {
      await pumpView(tester, populated(showImport: true, committing: true));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('scanner-import-input')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('save failure restores input with exact copy', (tester) async {
      await pumpView(
        tester,
        populated(showImport: true).copyWith(writeFailed: true),
      );
      expect(
        find.text(
          'Could not save signatures. Your previous records are unchanged.',
        ),
        findsOneWidget,
      );
      expect(find.text('keep this scan'), findsOneWidget);
    });
  });

  group('U11/U13/U14 exact feedback and lifecycle', () {
    testWidgets('committed actions use §6.6 strings', (tester) async {
      await pumpView(tester, populated(), onSave: () {}, onTrash: () {});
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.text('Signature saved.'), findsOneWidget);

      await pumpView(tester, populated(showImport: true), onImport: () {});
      await tester.tap(find.byKey(const Key('import-commit')));
      await tester.pump();
      expect(find.text(F5Fixtures.successMessage), findsOneWidget);

      await pumpView(tester, populated(), onTrash: () {});
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();
      expect(find.text('Moved 1 signatures to Trash.'), findsOneWidget);
    });

    testWidgets('observation, edited, and verified times stay distinct', (
      tester,
    ) async {
      final selected = F5Fixtures.abcExisting();
      await pumpView(
        tester,
        SignatureNotebookViewModel(
          characterId: kCharacter7,
          characterName: 'Pilot Seven',
          systemId: kAlphaSystemId,
          systemName: 'Alpha',
          signatures: [selected],
          selected: selected,
          connection: LocalConnection(
            id: 'link-1',
            characterId: kCharacter7,
            episodeId: selected.episodeId,
            fromSystemId: kAlphaSystemId,
            toSystemId: kTheraSystemId,
            verifiedAt: DateTime.utc(2026, 9, 15, 11, 30),
          ),
        ),
      );
      expect(find.textContaining('Observed'), findsOneWidget);
      expect(find.textContaining('Edited'), findsOneWidget);
      expect(find.textContaining('Verified'), findsOneWidget);
    });

    testWidgets('connection editor has three explicit controls', (
      tester,
    ) async {
      await pumpView(
        tester,
        populated().copyWith(
          connection: LocalConnection(
            id: 'link-1',
            characterId: kCharacter7,
            episodeId: 'episode-abc',
            fromSystemId: kAlphaSystemId,
            toSystemId: kTheraSystemId,
          ),
        ),
      );
      expect(find.text('Type seen here'), findsOneWidget);
      expect(find.text('Known originating type'), findsOneWidget);
      expect(find.text('Originating type side'), findsOneWidget);
      expect(find.textContaining('Eligible route edge'), findsNothing);
    });

    testWidgets('verify and close use committed copy', (tester) async {
      await pumpView(
        tester,
        populated().copyWith(
          connection: LocalConnection(
            id: 'link-1',
            characterId: kCharacter7,
            episodeId: 'episode-abc',
            fromSystemId: kAlphaSystemId,
            toSystemId: kTheraSystemId,
          ),
        ),
        onVerify: () {},
        onClose: () {},
      );
      await tester.tap(find.text('Confirm connection'));
      await tester.pump();
      expect(find.text('Connection verified.'), findsOneWidget);
      await tester.tap(find.text('Mark closed'));
      await tester.pump();
      expect(find.text('Connection marked closed.'), findsOneWidget);
    });

    testWidgets('trash restore and permanent delete are confirmed', (
      tester,
    ) async {
      final trashed = TrackedSignature(
        id: 'sig-abc',
        characterId: kCharacter7,
        systemId: kAlphaSystemId,
        code: 'ABC-123',
        episodeId: 'episode-abc',
        state: SignatureState.trash,
        retiredAt: kExplorationT0,
        retiredReason: 'pruned',
        lastSeenAt: DateTime.utc(2026, 9, 14, 12),
      );
      await pumpView(
        tester,
        SignatureNotebookViewModel(
          characterId: kCharacter7,
          characterName: 'Pilot Seven',
          systemId: kAlphaSystemId,
          systemName: 'Alpha',
          signatures: [trashed],
          showTrash: true,
        ),
        onRestore: () {},
        onDeletePermanent: () {},
      );
      expect(find.textContaining('pruned'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pump();
      expect(find.text('Signature restored.'), findsOneWidget);
      expect(find.textContaining('verified'), findsNothing);

      await tester.tap(find.text('Permanently delete'));
      await tester.pump();
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.textContaining('1 signature'), findsWidgets);
      await tester.tap(find.text('Delete permanently'));
      await tester.pump();
      expect(find.text('Permanently deleted 1 signatures.'), findsOneWidget);
    });
  });

  group('U02/U03/U18 layout and a11y', () {
    testWidgets('320/600/1100/1440 and 200% text do not overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(320, 640),
        Size(600, 800),
        Size(1100, 800),
        Size(1440, 900),
      ]) {
        await pumpView(tester, populated(), size: size, textScale: 2);
        expect(tester.takeException(), isNull, reason: '$size');
      }
    });

    testWidgets('icon-only actions have tooltips and text status', (
      tester,
    ) async {
      await pumpView(tester, populated());
      expect(find.byTooltip('Paste scanner results'), findsOneWidget);
      expect(find.byTooltip('Move to Trash'), findsOneWidget);
      expect(find.textContaining('Active'), findsWidgets);
    });
  });
}

extension on SignatureNotebookViewModel {
  SignatureNotebookViewModel copyWith({
    LocalConnection? connection,
    ImportPreview? preview,
    bool? pasteTooLarge,
    bool? revisionChanged,
    bool? writeFailed,
    bool? zeroValidSelected,
  }) {
    return SignatureNotebookViewModel(
      characterId: characterId,
      characterName: characterName,
      systemId: systemId,
      systemName: systemName,
      signatures: signatures,
      selected: selected,
      connection: connection ?? this.connection,
      preview: preview ?? this.preview,
      pasteInput: pasteInput,
      showImport: showImport,
      showTrash: showTrash,
      committing: committing,
      revisionChanged: revisionChanged ?? this.revisionChanged,
      clipboardEmpty: clipboardEmpty,
      clipboardError: clipboardError,
      pasteTooLarge: pasteTooLarge ?? this.pasteTooLarge,
      writeFailed: writeFailed ?? this.writeFailed,
      zeroValidSelected: zeroValidSelected ?? this.zeroValidSelected,
    );
  }

  SignatureNotebookViewModel copyWithClipboard({
    bool empty = false,
    bool error = false,
  }) {
    return SignatureNotebookViewModel(
      characterId: characterId,
      characterName: characterName,
      systemId: systemId,
      systemName: systemName,
      signatures: signatures,
      selected: selected,
      connection: connection,
      preview: preview,
      pasteInput: pasteInput,
      showImport: showImport,
      showTrash: showTrash,
      committing: committing,
      revisionChanged: revisionChanged,
      clipboardEmpty: empty,
      clipboardError: error,
      pasteTooLarge: pasteTooLarge,
      writeFailed: writeFailed,
      zeroValidSelected: zeroValidSelected,
    );
  }
}
