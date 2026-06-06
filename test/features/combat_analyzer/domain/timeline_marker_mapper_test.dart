import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_aar_report.dart';
import 'package:mimir/features/combat_analyzer/domain/combat_log_parser.dart';
import 'package:mimir/features/combat_analyzer/domain/parsed_combat_encounter.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/damage_chart_painter.dart';

void main() {
  group('TimelineMarkerMapper', () {
    test(
      'places moments by relative second, event id, ISO time, and HH:mm:ss',
      () {
        final encounter = CombatLogParser.parseLines([
          'Listener: Pilot',
          '[ 2026.05.20 20:00:00 ] (combat) 100 to Enemy - Hobgoblin II - Hits',
          '[ 2026.05.20 20:00:05 ] (combat) 50 from Enemy - Rocket - Hits',
          '[ 2026.05.20 20:00:10 ] (combat) 200 to Enemy - Hobgoblin II - Hits',
        ]).single;

        final resolution = TimelineMarkerMapper.resolve(
          keyMoments: [
            const AarKeyMoment(
              timestamp: '',
              relativeSecond: 2,
              category: 'opening',
              severity: 'low',
              title: 'Relative',
              details: '',
              eventIds: [],
            ),
            const AarKeyMoment(
              timestamp: '',
              category: 'pressure',
              severity: 'medium',
              title: 'Event',
              details: '',
              eventIds: ['e2'],
            ),
            const AarKeyMoment(
              timestamp: '2026-05-20T20:00:10.000Z',
              category: 'finish',
              severity: 'high',
              title: 'ISO',
              details: '',
              eventIds: [],
            ),
            const AarKeyMoment(
              timestamp: '20:00:05',
              category: 'damage_spike',
              severity: 'medium',
              title: 'Clock',
              details: '',
              eventIds: [],
            ),
            const AarKeyMoment(
              timestamp: 'not-a-time',
              category: 'unknown',
              severity: 'low',
              title: 'Unplaced',
              details: '',
              eventIds: [],
            ),
          ],
          events: encounter.events,
          startTime: encounter.startTime,
          durationSeconds: encounter.durationSeconds,
        );

        expect(resolution.placed.map((marker) => marker.second), [2, 5, 5, 10]);
        expect(resolution.unplaced.single.title, 'Unplaced');
      },
    );

    test('uses compact marker tooltip text', () {
      final marker = AarTimelineMarker.fromMoment(
        const AarKeyMoment(
          timestamp: '',
          relativeSecond: 19,
          category: 'mistake',
          severity: 'high',
          title: 'Scram pressure established late',
          details:
              'The full tactical explanation is useful in the report, but too long for a chart hover.',
          eventIds: [],
        ),
        19,
      );

      expect(marker.tooltip, '+00:19 Scram pressure established late');
      expect(marker.tooltip, isNot(contains('full tactical explanation')));
    });

    testWidgets(
      'timeline legend includes damage series and marker categories',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 640,
                height: 320,
                child: AarTimelineChart(
                  points: const [
                    CombatTimelinePoint(second: 0, outgoing: 0, incoming: 0),
                    CombatTimelinePoint(
                      second: 30,
                      outgoing: 100,
                      incoming: 200,
                    ),
                    CombatTimelinePoint(
                      second: 60,
                      outgoing: 240,
                      incoming: 320,
                    ),
                  ],
                  keyMoments: const [
                    AarKeyMoment(
                      timestamp: '',
                      relativeSecond: 12,
                      category: 'opening',
                      severity: 'low',
                      title: 'Opening',
                      details: 'Opening detail',
                      eventIds: [],
                    ),
                    AarKeyMoment(
                      timestamp: '',
                      relativeSecond: 28,
                      category: 'pressure',
                      severity: 'medium',
                      title: 'Pressure',
                      details: 'Pressure detail',
                      eventIds: [],
                    ),
                  ],
                  events: const [],
                  startTime: DateTime.utc(2026, 5, 20, 20),
                  durationSeconds: 60,
                  pilotName: 'Pilot',
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Pilot'), findsOneWidget);
        expect(find.text('Opposing damage'), findsOneWidget);
        expect(find.text('Opening'), findsOneWidget);
        expect(find.text('Pressure'), findsOneWidget);
      },
    );

    testWidgets('timeline marker hover uses custom painter label only', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 320,
              child: AarTimelineChart(
                points: const [
                  CombatTimelinePoint(second: 0, outgoing: 0, incoming: 0),
                  CombatTimelinePoint(second: 30, outgoing: 100, incoming: 200),
                ],
                keyMoments: const [
                  AarKeyMoment(
                    timestamp: '',
                    relativeSecond: 12,
                    category: 'opening',
                    severity: 'low',
                    title: 'Opening',
                    details: 'Opening detail',
                    eventIds: [],
                  ),
                ],
                events: const [],
                startTime: DateTime.utc(2026, 5, 20, 20),
                durationSeconds: 30,
                pilotName: 'Pilot',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Tooltip), findsNothing);
    });
  });
}
