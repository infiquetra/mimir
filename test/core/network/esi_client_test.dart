import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/network/esi_client.dart';

void main() {
  group('EsiException', () {
    test('should have correct error type helpers', () {
      expect(
        const EsiException('Auth error', statusCode: 401).isAuthError,
        isTrue,
      );
      expect(
        const EsiException('Scope error', statusCode: 403).isScopeError,
        isTrue,
      );
      expect(
        const EsiException('Rate limit', statusCode: 420).isRateLimited,
        isTrue,
      );
      expect(
        const EsiException('Server error', statusCode: 500).isServerError,
        isTrue,
      );
      expect(
        const EsiException('Server error', statusCode: 502).isServerError,
        isTrue,
      );
      expect(
        const EsiException('Client error', statusCode: 400).isClientError,
        isTrue,
      );
      expect(
        const EsiException('Not found', statusCode: 404).isClientError,
        isTrue,
      );
    });

    test('should have correct toString representation', () {
      const exception = EsiException('Test error', statusCode: 400);
      expect(exception.toString(), contains('EsiException'));
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('400'));
    });

    test('should differentiate between server and client errors', () {
      const serverError = EsiException('Server error', statusCode: 503);
      const clientError = EsiException('Client error', statusCode: 422);

      expect(serverError.isServerError, isTrue);
      expect(serverError.isClientError, isFalse);
      expect(clientError.isClientError, isTrue);
      expect(clientError.isServerError, isFalse);
    });
  });

  group('CharacterPublicInfo', () {
    test('should parse from JSON with required fields', () {
      final json = {
        'corporation_id': 98000001,
        'birthday': '2023-01-15T12:30:00Z',
        'name': 'Test Character',
      };

      final info = CharacterPublicInfo.fromJson(json);

      expect(info.corporationId, 98000001);
      expect(info.birthday, DateTime.parse('2023-01-15T12:30:00Z'));
      expect(info.name, 'Test Character');
      expect(info.allianceId, isNull);
      expect(info.description, isNull);
    });

    test('should parse from JSON with all optional fields', () {
      final json = {
        'corporation_id': 98000001,
        'birthday': '2023-01-15T12:30:00Z',
        'name': 'Test Character',
        'alliance_id': 99000001,
        'description': 'A test character description',
        'faction_id': 500001,
        'title': 'Fleet Commander',
      };

      final info = CharacterPublicInfo.fromJson(json);

      expect(info.allianceId, 99000001);
      expect(info.description, 'A test character description');
      expect(info.factionId, 500001);
      expect(info.title, 'Fleet Commander');
    });
  });

  group('CharacterSkills', () {
    test('should parse from JSON', () {
      final json = {
        'total_sp': 5000000,
        'unallocated_sp': 100000,
        'skills': [
          {
            'skill_id': 3327,
            'trained_skill_level': 5,
            'skillpoints_in_skill': 256000,
            'active_skill_level': 5,
          },
          {
            'skill_id': 3386,
            'trained_skill_level': 4,
            'skillpoints_in_skill': 45255,
            'active_skill_level': 4,
          },
        ],
      };

      final skills = CharacterSkills.fromJson(json);

      expect(skills.totalSp, 5000000);
      expect(skills.unallocatedSp, 100000);
      expect(skills.skills.length, 2);
      expect(skills.skills[0].skillId, 3327);
      expect(skills.skills[0].trainedSkillLevel, 5);
      expect(skills.skills[1].skillId, 3386);
    });

    test('should handle null unallocated_sp', () {
      final json = {'total_sp': 5000000, 'skills': []};

      final skills = CharacterSkills.fromJson(json);

      expect(skills.totalSp, 5000000);
      expect(skills.unallocatedSp, isNull);
    });
  });

  group('CharacterAttributes', () {
    test('should parse from JSON', () {
      final json = {
        'intelligence': 20,
        'memory': 19,
        'perception': 21,
        'willpower': 20,
        'charisma': 17,
        'bonus_remaps': 2,
        'last_remap_date': '2023-06-15T00:00:00Z',
        'accrued_remap_cooldown_date': '2024-06-15T00:00:00Z',
      };

      final attrs = CharacterAttributes.fromJson(json);

      expect(attrs.intelligence, 20);
      expect(attrs.memory, 19);
      expect(attrs.perception, 21);
      expect(attrs.willpower, 20);
      expect(attrs.charisma, 17);
      expect(attrs.bonusRemaps, 2);
      expect(attrs.lastRemapDate, isNotNull);
      expect(attrs.accruedRemapCooldownDate, isNotNull);
    });

    test('should calculate SP per hour correctly', () {
      const attrs = CharacterAttributes(
        intelligence: 20,
        memory: 20,
        perception: 20,
        willpower: 20,
        charisma: 20,
      );

      // SP/hour = (primary + secondary/2) * 60
      // With 20 primary and 20 secondary: (20 + 10) * 60 = 1800 SP/hour
      expect(attrs.spPerHour(165, 166), 1800.0); // Intelligence + Memory
    });

    test('should handle attribute ID mapping', () {
      const attrs = CharacterAttributes(
        intelligence: 25,
        memory: 22,
        perception: 20,
        willpower: 19,
        charisma: 17,
      );

      // 164 = Charisma, 165 = Intelligence, 166 = Memory, 167 = Perception, 168 = Willpower
      expect(
        attrs.spPerHour(164, 165),
        (17 + 25 / 2) * 60,
      ); // Charisma + Intelligence
      expect(
        attrs.spPerHour(167, 168),
        (20 + 19 / 2) * 60,
      ); // Perception + Willpower
    });
  });

  group('CorporationInfo', () {
    test('should parse from JSON with required fields', () {
      final json = {
        'name': 'Test Corporation',
        'ticker': 'TEST',
        'member_count': 150,
        'ceo_id': 90000001,
      };

      final corp = CorporationInfo.fromJson(json);

      expect(corp.name, 'Test Corporation');
      expect(corp.ticker, 'TEST');
      expect(corp.memberCount, 150);
      expect(corp.ceoId, 90000001);
    });

    test('should parse from JSON with all optional fields', () {
      final json = {
        'name': 'Test Corporation',
        'ticker': 'TEST',
        'member_count': 150,
        'ceo_id': 90000001,
        'alliance_id': 99000001,
        'description': 'A test corporation',
        'date_founded': '2020-01-01T00:00:00Z',
        'home_station_id': 60003760,
        'tax_rate': 0.10,
        'url': 'https://test.corp',
        'war_eligible': true,
      };

      final corp = CorporationInfo.fromJson(json);

      expect(corp.allianceId, 99000001);
      expect(corp.description, 'A test corporation');
      expect(corp.dateFounded, isNotNull);
      expect(corp.homeStationId, 60003760);
      expect(corp.taxRate, 0.10);
      expect(corp.url, 'https://test.corp');
      expect(corp.warEligible, isTrue);
    });
  });

  group('AllianceInfo', () {
    test('should parse from JSON', () {
      final json = {
        'name': 'Test Alliance',
        'ticker': 'TSTA',
        'creator_corporation_id': 98000001,
        'creator_id': 90000001,
        'date_founded': '2019-06-15T00:00:00Z',
        'executor_corporation_id': 98000002,
        'faction_id': 500001,
      };

      final alliance = AllianceInfo.fromJson(json);

      expect(alliance.name, 'Test Alliance');
      expect(alliance.ticker, 'TSTA');
      expect(alliance.creatorCorporationId, 98000001);
      expect(alliance.creatorId, 90000001);
      expect(alliance.dateFounded, DateTime.parse('2019-06-15T00:00:00Z'));
      expect(alliance.executorCorporationId, 98000002);
      expect(alliance.factionId, 500001);
    });
  });

  group('SkillQueueItem', () {
    test('should parse from JSON with required fields', () {
      final json = {'queue_position': 0, 'skill_id': 3327, 'finished_level': 5};

      final item = SkillQueueItem.fromJson(json);

      expect(item.queuePosition, 0);
      expect(item.skillId, 3327);
      expect(item.finishedLevel, 5);
      expect(item.startDate, isNull);
      expect(item.finishDate, isNull);
    });

    test('should parse from JSON with all fields', () {
      final json = {
        'queue_position': 0,
        'skill_id': 3327,
        'finished_level': 5,
        'start_date': '2024-01-15T10:00:00Z',
        'finish_date': '2024-01-16T14:30:00Z',
        'training_start_sp': 181200,
        'level_end_sp': 256000,
        'level_start_sp': 45255,
      };

      final item = SkillQueueItem.fromJson(json);

      expect(item.startDate, DateTime.parse('2024-01-15T10:00:00Z'));
      expect(item.finishDate, DateTime.parse('2024-01-16T14:30:00Z'));
      expect(item.trainingStartSp, 181200);
      expect(item.levelEndSp, 256000);
      expect(item.levelStartSp, 45255);
    });
  });

  group('WalletJournalItem', () {
    test('should parse from JSON with required fields', () {
      final json = {
        'id': 1234567890,
        'amount': 1000000.50,
        'balance': 5000000.75,
        'ref_type': 'market_escrow',
        'date': '2024-01-15T12:00:00Z',
      };

      final item = WalletJournalItem.fromJson(json);

      expect(item.id, 1234567890);
      expect(item.amount, 1000000.50);
      expect(item.balance, 5000000.75);
      expect(item.refType, 'market_escrow');
      expect(item.date, DateTime.parse('2024-01-15T12:00:00Z'));
    });

    test('should parse from JSON with all fields', () {
      final json = {
        'id': 1234567890,
        'amount': -500000.00,
        'balance': 4500000.75,
        'ref_type': 'player_donation',
        'date': '2024-01-15T12:00:00Z',
        'first_party_id': 90000001,
        'second_party_id': 90000002,
        'description': 'Payment for services',
        'reason': 'Thanks!',
        'context_id': 12345,
        'context_id_type': 'contract_id',
      };

      final item = WalletJournalItem.fromJson(json);

      expect(item.firstPartyId, 90000001);
      expect(item.secondPartyId, 90000002);
      expect(item.description, 'Payment for services');
      expect(item.reason, 'Thanks!');
      expect(item.contextId, 12345);
      expect(item.contextIdType, 'contract_id');
    });

    test('should handle integer amounts', () {
      final json = {
        'id': 1234567890,
        'amount': 1000000, // Integer, not double
        'balance': 5000000, // Integer, not double
        'ref_type': 'bounty_prizes',
        'date': '2024-01-15T12:00:00Z',
      };

      final item = WalletJournalItem.fromJson(json);

      expect(item.amount, 1000000.0);
      expect(item.balance, 5000000.0);
    });
  });

  group('Group E — killmail names and faction', () {
    test('E.9 rawKillmail names survive the round-trip', () {
      final attacker = EsiKillmailAttacker.fromJson({
        'character_id': 9001,
        'character_name': 'Artem S3',
        'corporation_id': 98000002,
        'ship_type_id': 24702,
        'weapon_type_id': 2410,
        'damage_done': 4200,
        'final_blow': false,
        'faction_id': 500020,
      });
      expect(attacker.characterName, 'Artem S3');
      expect(attacker.factionId, 500020);
      expect(attacker.isPlayer, isTrue);
      expect(attacker.toJson()['character_name'], 'Artem S3');
      expect(attacker.toJson()['faction_id'], 500020);
      final attackerRoundTrip = EsiKillmailAttacker.fromJson(attacker.toJson());
      expect(attackerRoundTrip.characterName, 'Artem S3');
      expect(attackerRoundTrip.factionId, 500020);

      final npc = EsiKillmailAttacker.fromJson({
        'ship_type_id': 30001,
        'damage_done': 1400,
        'final_blow': false,
        'faction_id': 500020,
      });
      expect(npc.isPlayer, isFalse);
      expect(npc.characterId, isNull);
      expect(npc.factionId, 500020);

      final victim = EsiKillmailVictim.fromJson({
        'character_id': 7001,
        'character_name': 'Vex Kalari',
        'ship_type_id': 587,
        'damage_taken': 300,
        'faction_id': 500001,
        'items': <Map<String, dynamic>>[],
      });
      expect(victim.characterName, 'Vex Kalari');
      expect(victim.factionId, 500001);
      expect(victim.toJson()['character_name'], 'Vex Kalari');
      expect(victim.toJson()['faction_id'], 500001);
      final victimRoundTrip = EsiKillmailVictim.fromJson(victim.toJson());
      expect(victimRoundTrip.characterName, 'Vex Kalari');
      expect(victimRoundTrip.factionId, 500001);

      final detail = EsiKillmailDetail.fromJson({
        'killmail_id': 1234567,
        'killmail_time': '2026-05-20T20:01:00Z',
        'solar_system_id': 30000142,
        'victim': {
          'character_id': 7001,
          'character_name': 'Vex Kalari',
          'ship_type_id': 587,
          'damage_taken': 300,
          'items': <Map<String, dynamic>>[],
        },
        'attackers': [
          {
            'character_id': 9001,
            'character_name': 'Artem S3',
            'ship_type_id': 24702,
            'damage_done': 1000,
            'final_blow': true,
            'faction_id': 500020,
          },
        ],
      });
      expect(detail.attackers.first.characterName, 'Artem S3');
      expect(detail.victim.characterName, 'Vex Kalari');
      expect(detail.attackers.first.factionId, 500020);
      final detailRoundTrip = EsiKillmailDetail.fromJson(detail.toJson());
      expect(detailRoundTrip.attackers.first.characterName, 'Artem S3');
      expect(detailRoundTrip.victim.characterName, 'Vex Kalari');
      expect(detailRoundTrip.attackers.first.factionId, 500020);
    });
  });
}
