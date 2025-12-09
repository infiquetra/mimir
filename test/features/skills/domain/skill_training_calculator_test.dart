import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/skills/domain/skill_training_calculator.dart';
import 'package:mocktail/mocktail.dart';

class MockSdeService extends Mock implements SdeService {}

void main() {
  late MockSdeService mockSdeService;
  late SkillTrainingCalculator calculator;

  setUp(() {
    mockSdeService = MockSdeService();
    calculator = SkillTrainingCalculator(sdeService: mockSdeService);
    reset(mockSdeService);
  });

  group('calculateSpRequired', () {
    test('rank 1 skill from 0→1 requires 250 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 1,
        fromLevel: 0,
        toLevel: 1,
      );

      expect(sp, 250); // 250 × 1 × 2^0
    });

    test('rank 1 skill from 0→5 requires 7,750 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 1,
        fromLevel: 0,
        toLevel: 5,
      );

      // 250 × 1 × (2^0 + 2^1 + 2^2 + 2^3 + 2^4)
      // = 250 × 1 × (1 + 2 + 4 + 8 + 16)
      // = 250 × 31 = 7,750
      expect(sp, 7750);
    });

    test('rank 5 skill from 0→5 requires 38,750 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 5,
        fromLevel: 0,
        toLevel: 5,
      );

      // 250 × 5 × 31 = 38,750
      expect(sp, 38750);
    });

    test('rank 1 skill from 3→4 requires 2,000 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 1,
        fromLevel: 3,
        toLevel: 4,
      );

      // 250 × 1 × 2^3 = 250 × 8 = 2,000
      expect(sp, 2000);
    });

    test('same level returns 0 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 1,
        fromLevel: 3,
        toLevel: 3,
      );

      expect(sp, 0);
    });

    test('fromLevel > toLevel returns 0 SP', () {
      final sp = calculator.calculateSpRequired(
        skillRank: 1,
        fromLevel: 4,
        toLevel: 2,
      );

      expect(sp, 0);
    });

    test('invalid fromLevel throws ArgumentError', () {
      expect(
        () => calculator.calculateSpRequired(
          skillRank: 1,
          fromLevel: -1,
          toLevel: 5,
        ),
        throwsArgumentError,
      );

      expect(
        () => calculator.calculateSpRequired(
          skillRank: 1,
          fromLevel: 6,
          toLevel: 7,
        ),
        throwsArgumentError,
      );
    });

    test('invalid toLevel throws ArgumentError', () {
      expect(
        () => calculator.calculateSpRequired(
          skillRank: 1,
          fromLevel: 0,
          toLevel: 6,
        ),
        throwsArgumentError,
      );

      expect(
        () => calculator.calculateSpRequired(
          skillRank: 1,
          fromLevel: 0,
          toLevel: -1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('calculateTrainingTime', () {
    test('default attributes (20/20) = 30 SP/min', () {
      final duration = calculator.calculateTrainingTime(
        spRequired: 900,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );

      // Training rate = 20 + (20 / 2) = 30 SP/min
      // Time = 900 / 30 = 30 minutes
      expect(duration, const Duration(minutes: 30));
    });

    test('custom attributes (25/20) = 35 SP/min', () {
      final duration = calculator.calculateTrainingTime(
        spRequired: 1050,
        primaryAttribute: 25,
        secondaryAttribute: 20,
      );

      // Training rate = 25 + (20 / 2) = 35 SP/min
      // Time = 1050 / 35 = 30 minutes
      expect(duration, const Duration(minutes: 30));
    });

    test('zero SP returns Duration.zero', () {
      final duration = calculator.calculateTrainingTime(
        spRequired: 0,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );

      expect(duration, Duration.zero);
    });

    test('negative SP returns Duration.zero', () {
      final duration = calculator.calculateTrainingTime(
        spRequired: -100,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );

      expect(duration, Duration.zero);
    });

    test('fractional minutes are rounded up', () {
      final duration = calculator.calculateTrainingTime(
        spRequired: 50,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );

      // Training rate = 30 SP/min
      // Time = 50 / 30 = 1.67 minutes → ceil = 2 minutes
      expect(duration, const Duration(minutes: 2));
    });
  });

  group('calculateSkillTrainingTime', () {
    test('combines SP and time calculation', () {
      final duration = calculator.calculateSkillTrainingTime(
        skillRank: 1,
        fromLevel: 0,
        toLevel: 1,
        primaryAttribute: 20,
        secondaryAttribute: 20,
      );

      // SP = 250
      // Training rate = 30 SP/min
      // Time = 250 / 30 = 8.33 → ceil = 9 minutes
      expect(duration, const Duration(minutes: 9));
    });
  });

  group('calculateSpRequiredFromSde', () {
    test('uses skill rank from SDE', () async {
      const skillId = 3301; // Mechanics
      const skillRank = 3;

      when(() => mockSdeService.getSkillRank(skillId))
          .thenAnswer((_) async => skillRank);

      final sp = await calculator.calculateSpRequiredFromSde(
        skillId: skillId,
        fromLevel: 0,
        toLevel: 5,
      );

      // 250 × 3 × 31 = 23,250
      expect(sp, 23250);
      verify(() => mockSdeService.getSkillRank(skillId)).called(1);
    });

    test('falls back to rank 1 when skill rank is null', () async {
      const skillId = 9999; // Unknown skill

      when(() => mockSdeService.getSkillRank(skillId))
          .thenAnswer((_) async => null);

      final sp = await calculator.calculateSpRequiredFromSde(
        skillId: skillId,
        fromLevel: 0,
        toLevel: 5,
      );

      // Falls back to rank 1: 250 × 1 × 31 = 7,750
      expect(sp, 7750);
      verify(() => mockSdeService.getSkillRank(skillId)).called(1);
    });
  });

  group('calculateTrainingTimeFromSde', () {
    test('uses character attributes from ESI', () async {
      const skillId = 3301; // Mechanics
      const spRequired = 900;

      final attributes = (
        primary: 'perception',
        secondary: 'willpower',
      );

      final characterAttributes = CharacterAttributes(
        charisma: 20,
        intelligence: 20,
        memory: 20,
        perception: 25, // Primary
        willpower: 20, // Secondary
      );

      when(() => mockSdeService.getSkillAttributes(skillId))
          .thenAnswer((_) async => attributes);

      final duration = await calculator.calculateTrainingTimeFromSde(
        skillId: skillId,
        spRequired: spRequired,
        characterAttributes: characterAttributes,
      );

      // Training rate = 25 + (20 / 2) = 35 SP/min
      // Time = 900 / 35 = 25.71 → ceil = 26 minutes
      expect(duration, const Duration(minutes: 26));
      verify(() => mockSdeService.getSkillAttributes(skillId)).called(1);
    });

    test('falls back to 20/20 when attributes are null', () async {
      const skillId = 9999; // Unknown skill
      const spRequired = 900;

      final characterAttributes = CharacterAttributes(
        charisma: 25,
        intelligence: 25,
        memory: 25,
        perception: 25,
        willpower: 25,
      );

      when(() => mockSdeService.getSkillAttributes(skillId))
          .thenAnswer((_) async => null);

      final duration = await calculator.calculateTrainingTimeFromSde(
        skillId: skillId,
        spRequired: spRequired,
        characterAttributes: characterAttributes,
      );

      // Falls back to 20/20: training rate = 30 SP/min
      // Time = 900 / 30 = 30 minutes
      expect(duration, const Duration(minutes: 30));
      verify(() => mockSdeService.getSkillAttributes(skillId)).called(1);
    });

    test('returns Duration.zero for zero SP', () async {
      const skillId = 3301;
      const spRequired = 0;

      final characterAttributes = CharacterAttributes(
        charisma: 20,
        intelligence: 20,
        memory: 20,
        perception: 20,
        willpower: 20,
      );

      final duration = await calculator.calculateTrainingTimeFromSde(
        skillId: skillId,
        spRequired: spRequired,
        characterAttributes: characterAttributes,
      );

      expect(duration, Duration.zero);
      // Should not call SDE when SP is zero
      verifyNever(() => mockSdeService.getSkillAttributes(skillId));
    });
  });

  group('calculateSkillTrainingTimeFromSde', () {
    test('combines SDE SP calculation and attribute-based time calculation', () async {
      const skillId = 3301; // Mechanics
      const skillRank = 1;

      final attributes = (
        primary: 'perception',
        secondary: 'willpower',
      );

      final characterAttributes = CharacterAttributes(
        charisma: 20,
        intelligence: 20,
        memory: 20,
        perception: 20,
        willpower: 20,
      );

      when(() => mockSdeService.getSkillRank(skillId))
          .thenAnswer((_) async => skillRank);
      when(() => mockSdeService.getSkillAttributes(skillId))
          .thenAnswer((_) async => attributes);

      final duration = await calculator.calculateSkillTrainingTimeFromSde(
        skillId: skillId,
        fromLevel: 0,
        toLevel: 1,
        characterAttributes: characterAttributes,
      );

      // SP = 250 (rank 1, level 0→1)
      // Training rate = 20 + (20 / 2) = 30 SP/min
      // Time = 250 / 30 = 8.33 → ceil = 9 minutes
      expect(duration, const Duration(minutes: 9));
      verify(() => mockSdeService.getSkillRank(skillId)).called(1);
      verify(() => mockSdeService.getSkillAttributes(skillId)).called(1);
    });
  });
}
