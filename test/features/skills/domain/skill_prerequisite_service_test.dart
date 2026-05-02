import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:mimir/core/sde/sde_service.dart';
import 'package:mimir/features/skills/data/skill_repository.dart';
import 'package:mimir/features/skills/domain/skill_prerequisite_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSdeService extends Mock implements SdeService {}

class MockSkillRepository extends Mock implements SkillRepository {}

void main() {
  late MockSdeService mockSdeService;
  late MockSkillRepository mockSkillRepository;
  late SkillPrerequisiteService service;

  setUp(() {
    mockSdeService = MockSdeService();
    mockSkillRepository = MockSkillRepository();
    service = SkillPrerequisiteService(
      sdeService: mockSdeService,
      skillRepository: mockSkillRepository,
    );

    reset(mockSdeService);
    reset(mockSkillRepository);

    when(() => mockSdeService.getSkillName(any<int>())).thenAnswer((_) async => null);
  });

  group('canTrainSkill', () {
    test('returns true when all prerequisites are met', () async {
      const characterId = 12345;
      const skillId = 3301; // Mechanics
      const targetLevel = 5;

      // Skill has no prerequisites
      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => []);

      final canTrain = await service.canTrainSkill(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(canTrain, true);
      verify(() => mockSdeService.getSkillPrerequisites(skillId)).called(1);
    });

    test('returns false when prerequisites are missing', () async {
      const characterId = 12345;
      const skillId = 11441; // Advanced Weapon Upgrades
      const targetLevel = 1;

      // Requires Weapon Upgrades V
      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
      ];

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 3); // Only has level III

      final canTrain = await service.canTrainSkill(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(canTrain, false);
      verify(() => mockSdeService.getSkillPrerequisites(skillId)).called(1);
      verify(() => mockSkillRepository.getTrainedLevel(characterId, 3318)).called(1);
    });

    test('returns true when all prerequisites are trained', () async {
      const characterId = 12345;
      const skillId = 11441; // Advanced Weapon Upgrades
      const targetLevel = 1;

      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
      ];

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 5); // Has level V

      final canTrain = await service.canTrainSkill(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(canTrain, true);
    });
  });

  group('getUnmetPrerequisites', () {
    test('returns empty list when no prerequisites exist', () async {
      const characterId = 12345;
      const skillId = 3301; // Mechanics
      const targetLevel = 5;

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => []);

      final unmet = await service.getUnmetPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(unmet, isEmpty);
    });

    test('returns empty list when all prerequisites are met', () async {
      const characterId = 12345;
      const skillId = 11441;
      const targetLevel = 1;

      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
      ];

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 5);
      when(() => mockSdeService.getSkillName(3318))
          .thenAnswer((_) async => 'Weapon Upgrades');

      final unmet = await service.getUnmetPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(unmet, isEmpty);
    });

    test('returns unmet prerequisites with trained and required levels', () async {
      const characterId = 12345;
      const skillId = 11441; // Advanced Weapon Upgrades
      const targetLevel = 1;

      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3327, requiredLevel: 3),
      ];

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 3); // Missing 2 levels
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3327))
          .thenAnswer((_) async => 0); // Untrained
      when(() => mockSdeService.getSkillName(3318))
          .thenAnswer((_) async => 'Weapon Upgrades');
      when(() => mockSdeService.getSkillName(3327))
          .thenAnswer((_) async => 'Spaceship Command');

      final unmet = await service.getUnmetPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(unmet, hasLength(2));

      // First prerequisite (Weapon Upgrades)
      expect(unmet[0].skillId, 3318);
      expect(unmet[0].skillName, 'Weapon Upgrades');
      expect(unmet[0].requiredLevel, 5);
      expect(unmet[0].trainedLevel, 3);
      expect(unmet[0].isUntrained, false);

      // Second prerequisite (Spaceship Command)
      expect(unmet[1].skillId, 3327);
      expect(unmet[1].skillName, 'Spaceship Command');
      expect(unmet[1].requiredLevel, 3);
      expect(unmet[1].trainedLevel, 0);
      expect(unmet[1].isUntrained, true);
    });

    test('handles missing skill names with fallback', () async {
      const characterId = 12345;
      const skillId = 11441;
      const targetLevel = 1;

      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 9999, requiredLevel: 1),
      ];

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 9999))
          .thenAnswer((_) async => 0);
      when(() => mockSdeService.getSkillName(9999))
          .thenAnswer((_) async => null); // Missing name

      final unmet = await service.getUnmetPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(unmet, hasLength(1));
      expect(unmet[0].skillName, 'Skill #9999'); // Fallback format
    });
  });

  group('getAllPrerequisites', () {
    test('returns empty list when no prerequisites exist', () async {
      const characterId = 12345;
      const skillId = 3301;
      const targetLevel = 5;

      when(() => mockSdeService.getSkillPrerequisites(skillId))
          .thenAnswer((_) async => []);

      final all = await service.getAllPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(all, isEmpty);
    });

    test('returns direct prerequisites only (depth 0)', () async {
      const characterId = 12345;
      const skillId = 11441; // Advanced Weapon Upgrades
      const targetLevel = 1;

      // Advanced Weapon Upgrades requires Weapon Upgrades V
      when(() => mockSdeService.getSkillPrerequisites(11441))
          .thenAnswer((_) async => [
                SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
              ]);
      // Weapon Upgrades has no prerequisites
      when(() => mockSdeService.getSkillPrerequisites(3318))
          .thenAnswer((_) async => []);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 3); // Needs training
      when(() => mockSdeService.getSkillName(3318))
          .thenAnswer((_) async => 'Weapon Upgrades');

      final all = await service.getAllPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      expect(all, hasLength(1));
      expect(all[0].skillId, 3318);
      expect(all[0].skillName, 'Weapon Upgrades');
      expect(all[0].requiredLevel, 5);
      expect(all[0].trainedLevel, 3);
      expect(all[0].depth, 0); // Direct prerequisite
      expect(all[0].forSkillId, 11441);
    });

    test('recursively finds nested prerequisites (depth 1+)', () async {
      const characterId = 12345;
      const skillId = 12485; // Interceptors (example)
      const targetLevel = 1;

      // Interceptors requires Caldari Frigate V
      when(() => mockSdeService.getSkillPrerequisites(12485))
          .thenAnswer((_) async => [
                SdeSkillRequirement(skillId: 0, requiredSkillId: 3327, requiredLevel: 5),
              ]);
      // Caldari Frigate requires Spaceship Command III
      when(() => mockSdeService.getSkillPrerequisites(3327))
          .thenAnswer((_) async => [
                SdeSkillRequirement(skillId: 0, requiredSkillId: 3301, requiredLevel: 3),
              ]);
      // Spaceship Command has no prerequisites
      when(() => mockSdeService.getSkillPrerequisites(3301))
          .thenAnswer((_) async => []);

      // Character has Spaceship Command III but not Caldari Frigate
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3327))
          .thenAnswer((_) async => 3); // Caldari Frigate III (need V)
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3301))
          .thenAnswer((_) async => 3); // Spaceship Command III (met!)

      when(() => mockSdeService.getSkillName(3327))
          .thenAnswer((_) async => 'Caldari Frigate');
      when(() => mockSdeService.getSkillName(3301))
          .thenAnswer((_) async => 'Spaceship Command');

      final all = await service.getAllPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      // Only Caldari Frigate is unmet (Spaceship Command III is already trained)
      expect(all, hasLength(1));
      expect(all[0].skillId, 3327);
      expect(all[0].skillName, 'Caldari Frigate');
      expect(all[0].requiredLevel, 5);
      expect(all[0].trainedLevel, 3);
      expect(all[0].depth, 0);
      expect(all[0].forSkillId, 12485);
    });

    test('handles circular dependency detection', () async {
      const characterId = 12345;
      const skillId = 100;
      const targetLevel = 1;

      // Circular: 100 → 101 → 100
      when(() => mockSdeService.getSkillPrerequisites(100))
          .thenAnswer((_) async => [
                SdeSkillRequirement(skillId: 0, requiredSkillId: 101, requiredLevel: 1),
              ]);
      when(() => mockSdeService.getSkillPrerequisites(101))
          .thenAnswer((_) async => [
                SdeSkillRequirement(skillId: 0, requiredSkillId: 100, requiredLevel: 1),
              ]);

      when(() => mockSkillRepository.getTrainedLevel(characterId, 101))
          .thenAnswer((_) async => 0);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 100))
          .thenAnswer((_) async => 0);

      when(() => mockSdeService.getSkillName(101))
          .thenAnswer((_) async => 'Skill 101');
      when(() => mockSdeService.getSkillName(100))
          .thenAnswer((_) async => 'Skill 100');

      // Should not infinite loop
      final all = await service.getAllPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      // Should detect cycle and stop
      expect(all, isNotEmpty);
      // Verify it didn't infinite loop by completing successfully
    });

    test('does not include already-trained prerequisites', () async {
      const characterId = 12345;
      const skillId = 11441;
      const targetLevel = 1;

      final prerequisites = [
        SdeSkillRequirement(skillId: 0, requiredSkillId: 3318, requiredLevel: 5),
      ];

      when(() => mockSdeService.getSkillPrerequisites(11441))
          .thenAnswer((_) async => prerequisites);
      when(() => mockSdeService.getSkillPrerequisites(3318))
          .thenAnswer((_) async => []);
      when(() => mockSkillRepository.getTrainedLevel(characterId, 3318))
          .thenAnswer((_) async => 5); // Already trained!
      when(() => mockSdeService.getSkillName(3318))
          .thenAnswer((_) async => 'Weapon Upgrades');

      final all = await service.getAllPrerequisites(
        characterId: characterId,
        skillId: skillId,
        targetLevel: targetLevel,
      );

      // Should not include already-trained prerequisite
      expect(all, isEmpty);
    });
  });
}
