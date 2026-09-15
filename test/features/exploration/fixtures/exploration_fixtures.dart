import 'package:mimir/features/exploration/domain/exploration_clock.dart';
import 'package:mimir/features/exploration/domain/exploration_notebook.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_reference.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart';
import 'package:mimir/features/exploration/domain/scanner_import.dart';

/// Product §8.1 T0 for every time fixture unless stated otherwise.
final kExplorationT0 = ExplorationClock.t0;

const kTheraSystemId = 31000005;
const kTurnurSystemId = 30002086;
const kAlphaSystemId = 9101;
const kCharacter7 = 7;
const kCharacter8 = 8;

const kB274TypeId = 30677;
const kK162TypeId = 30831;
const kI078TypeId = 92287;
const kC729V1TypeId = 94001;
const kC729V2TypeId = 94002;
const kQ001TypeId = 95001;
const kQ002TypeId = 95002;

/// Product F1 oracles at full precision before formatting.
class F1Oracle {
  static const b274LifetimeSeconds = 86400;
  static const b274TotalMassKg = 2000000000.0;
  static const b274JumpMassKg = 375000000.0;
  static const b274RegenKgPerCycle = 0.0;
  static const i078LifetimeSeconds = 16200;
  static const i078TotalMassKg = 100000000.0;
  static const i078JumpMassKg = 62000000.0;
  static const c729LifetimeSeconds = 43200;
  static const c729AgreedJumpKg = 410000000.0;
  static const c729V2JumpKg = 420000000.0;
  static const capitalJumpThresholdKg = 1000000000.0;
}

class F1Fixtures {
  static Map<String, dynamic> b274Raw() => {
    'typeId': kB274TypeId,
    'code': 'B274',
    'name': 'Wormhole B274',
    'rawTargetClass': 7,
    'rawMaxStableTimeMinutes': 1440,
    'rawTotalMassKg': F1Oracle.b274TotalMassKg,
    'rawJumpMassKg': F1Oracle.b274JumpMassKg,
    'rawRegenKg': 0,
  };

  static Map<String, dynamic> k162Raw() => {
    'typeId': kK162TypeId,
    'code': 'K162',
    'name': 'Wormhole K162',
  };

  static Map<String, dynamic> i078Raw() => {
    'typeId': kI078TypeId,
    'code': 'I078',
    'name': 'Wormhole I078',
    'rawTargetClass': 25,
    'rawMaxStableTimeMinutes': 270,
    'rawTotalMassKg': F1Oracle.i078TotalMassKg,
    'rawJumpMassKg': F1Oracle.i078JumpMassKg,
  };

  static Map<String, dynamic> c729V1Raw() => {
    'typeId': kC729V1TypeId,
    'code': 'C729',
    'name': 'Wormhole C729 V1',
    'rawTargetClass': -1,
    'rawTargetDistribution': 1,
    'rawMaxStableTimeMinutes': 720,
    'rawJumpMassKg': F1Oracle.c729AgreedJumpKg,
  };

  static Map<String, dynamic> c729V2AgreeRaw() => {
    'typeId': kC729V2TypeId,
    'code': 'C729',
    'name': 'Wormhole C729 V2',
    'rawTargetClass': -1,
    'rawTargetDistribution': 2,
    'rawMaxStableTimeMinutes': 720,
    'rawJumpMassKg': F1Oracle.c729AgreedJumpKg,
  };

  static Map<String, dynamic> c729V2ConflictRaw() => {
    ...c729V2AgreeRaw(),
    'rawJumpMassKg': F1Oracle.c729V2JumpKg,
  };

  static Map<String, dynamic> q001Raw() => {
    'typeId': kQ001TypeId,
    'code': 'Q001',
    'name': 'Synthetic Q001',
    'rawTargetClass': 1,
    'rawJumpMassKg': F1Oracle.capitalJumpThresholdKg,
  };

  static Map<String, dynamic> q002Raw() => {
    'typeId': kQ002TypeId,
    'code': 'Q002',
    'name': 'Synthetic Q002',
    'rawTargetClass': 1,
    'rawJumpMassKg': 999999999.0,
  };

  static WormholeTypeReference typeFromRaw(Map<String, dynamic> raw) {
    return WormholeTypeReference.fromRaw(
      typeId: raw['typeId'] as int,
      code: raw['code'] as String,
      name: raw['name'] as String,
      rawTargetClass: raw['rawTargetClass'] as int?,
      rawTargetDistribution: raw['rawTargetDistribution'] as int?,
      rawMaxStableTimeMinutes: raw['rawMaxStableTimeMinutes'] as int?,
      rawTotalMassKg: (raw['rawTotalMassKg'] as num?)?.toDouble(),
      rawJumpMassKg: (raw['rawJumpMassKg'] as num?)?.toDouble(),
      rawRegenKg: (raw['rawRegenKg'] as num?)?.toDouble(),
      recordedAt: kExplorationT0,
    );
  }

  static WormholeTypeReference get b274 => typeFromRaw(b274Raw());
  static WormholeTypeReference get k162 => typeFromRaw(k162Raw());
  static WormholeTypeReference get i078 => typeFromRaw(i078Raw());
  static WormholeTypeReference get q001 => typeFromRaw(q001Raw());
  static WormholeTypeReference get q002 => typeFromRaw(q002Raw());
}

/// Product §4.2 / F2 exact percentage-change vectors.
class F2Oracle {
  static const pulsarShield = [30, 44, 58, 72, 86, 100];
  static const pulsarSignature = [30, 44, 58, 72, 86, 100];
  static const pulsarArmorResonance = [15, 22, 29, 36, 43, 50];
  static const pulsarCapRechargeTime = [-15, -22, -29, -36, -43, -50];
  static const pulsarEnergyWarfare = [30, 44, 58, 72, 86, 100];
  static const pulsarBeacons = [30844, 30865, 30866, 30867, 30868, 30869];

  static const blackHoleInertia = [15, 22, 29, 36, 43, 50];
  static const blackHoleTargetRange = [30, 44, 58, 72, 86, 100];
  static const blackHoleMissileVelocity = [15, 22, 29, 36, 43, 50];
  static const blackHoleShipVelocity = [30, 44, 58, 72, 86, 100];
  static const blackHoleExplosionVelocity = [30, 44, 58, 72, 86, 100];
  static const blackHoleWeb = [-15, -22, -29, -36, -43, -50];
  static const blackHoleBeacons = [30845, 30850, 30851, 30852, 30853, 30854];

  static const cataclysmicLocalArmor = [-15, -22, -29, -36, -43, -50];
  static const cataclysmicLocalShield = [-15, -22, -29, -36, -43, -50];
  static const cataclysmicRemoteShield = [30, 44, 58, 72, 86, 100];
  static const cataclysmicRemoteArmor = [30, 44, 58, 72, 86, 100];
  static const cataclysmicCapCapacity = [30, 44, 58, 72, 86, 100];
  static const cataclysmicCapRecharge = [15, 22, 29, 36, 43, 50];
  static const cataclysmicRemoteCap = [-15, -22, -29, -36, -43, -50];
  static const cataclysmicBeacons = [30846, 30880, 30881, 30884, 30883, 30882];

  static const magnetarTargetRange = [-15, -22, -29, -36, -43, -50];
  static const magnetarTracking = [-15, -22, -29, -36, -43, -50];
  static const magnetarDamage = [30, 44, 58, 72, 86, 100];
  static const magnetarExplosionRadius = [30, 44, 58, 72, 86, 100];
  static const magnetarPainter = [-15, -22, -29, -36, -43, -50];
  static const magnetarBeacons = [30847, 30860, 30861, 30862, 30863, 30864];

  static const redGiantHeat = [15, 22, 29, 36, 43, 50];
  static const redGiantOverload = [30, 44, 58, 72, 86, 100];
  static const redGiantSmartbombRange = [30, 44, 58, 72, 86, 100];
  static const redGiantSmartbombDamage = [30, 44, 58, 72, 86, 100];
  static const redGiantBeacons = [30848, 30870, 30871, 30872, 30873, 30874];

  static const wolfRayetArmorHp = [30, 44, 58, 72, 86, 100];
  static const wolfRayetSignature = [-15, -22, -29, -36, -43, -50];
  static const wolfRayetShieldResonance = [15, 22, 29, 36, 43, 50];
  static const wolfRayetSmallWeapon = [60, 88, 116, 144, 172, 200];
  static const wolfRayetBeacons = [30849, 30875, 30876, 30877, 30878, 30879];

  static const families = EffectFamily.values;
  static const combinationCount = 36;

  static const resonanceOldResist = 0.50;
  static const resonancePercent = 50.0;
  static const resonanceNewResist = 0.25;
  static const multiplier130Percent = 30.0;
  static const magnetarS1ExplosionFrom100 = 130.0;
  static const wolfRayetS6SmallFrom100 = 300.0;
  static const pulsarS6CapFrom100 = 50.0;
}

class F2SecurityRow {
  const F2SecurityRow(this.raw, this.category, this.display);
  final double? raw;
  final SecurityCategory category;
  final String display;
}

class F2Fixtures {
  static const securityTable = <F2SecurityRow>[
    F2SecurityRow(-0.01, SecurityCategory.nullsec, '0.0'),
    F2SecurityRow(0, SecurityCategory.nullsec, '0.0'),
    F2SecurityRow(0.0001, SecurityCategory.lowsec, '0.1'),
    F2SecurityRow(0.049, SecurityCategory.lowsec, '0.1'),
    F2SecurityRow(0.05, SecurityCategory.lowsec, '0.1'),
    F2SecurityRow(0.449999, SecurityCategory.lowsec, '0.4'),
    F2SecurityRow(0.45, SecurityCategory.highsec, '0.5'),
    F2SecurityRow(null, SecurityCategory.unknown, 'Unknown'),
  ];

  static SystemReference j005926() => SystemReference(
    systemId: 96001,
    name: 'J005926',
    rawClass: 5,
    effectBeaconTypeId: 30848,
    visualSunTypeId: F2Oracle.pulsarBeacons.first,
  );

  static SystemReference j010569() => SystemReference(
    systemId: 96002,
    name: 'J010569',
    rawClass: 5,
    effectBeaconTypeId: 30849,
    visualSunTypeId: F2Oracle.redGiantBeacons.first,
  );

  static SystemReference class13() => SystemReference(
    systemId: 96013,
    name: 'J-CLASS13',
    rawClass: 13,
    effectBeaconTypeId: 30879,
  );

  static SystemReference thera() => SystemReference(
    systemId: kTheraSystemId,
    name: 'Thera',
    rawClass: 12,
    rawSecurity: -0.99,
  );

  static SystemReference pochven() => SystemReference(
    systemId: 10000070,
    name: 'Pochven',
    rawClass: 25,
    rawSecurity: -0.99,
  );
}

class F3Fixtures {
  static Map<String, dynamic> wireRecord({
    Object id = '42',
    bool? exitsOutward = true,
    String? inSignature = 'FAR-456',
    int remainingHours = 999,
    String? expiresAt = '2026-09-15T18:00:00Z',
    String maxShipSize = 'xlarge',
    bool completed = true,
    String signatureType = 'wormhole',
  }) {
    return {
      'id': id,
      'created_at': '2026-09-15T10:00:00Z',
      'updated_at': '2026-09-15T11:30:00Z',
      'completed': completed,
      'signature_type': signatureType,
      'out_system_id': kTurnurSystemId,
      'out_system_name': 'Turnur',
      'out_signature': 'HUB-123',
      'in_system_id': kAlphaSystemId,
      'in_system_name': 'Alpha',
      'in_system_class': 'hs',
      'in_region_id': 9201,
      'in_region_name': 'Fixture Region',
      'in_signature': inSignature,
      'wh_type': 'B274',
      'wh_exits_outward': exitsOutward,
      'max_ship_size': maxShipSize,
      'expires_at': expiresAt,
      'remaining_hours': remainingHours,
    };
  }

  static const providerKey = 'evescout:42';
  static final reportedUpdate = DateTime.utc(2026, 9, 15, 11, 30);
  static final expiresAt = DateTime.utc(2026, 9, 15, 18);
  static final stableAt4h = DateTime.utc(2026, 9, 15, 14);
  static final eolAt4hPlus1ms = DateTime.utc(2026, 9, 15, 14, 0, 0, 1);
}

class F4Fixtures {
  static final freshUntil = DateTime.utc(2026, 9, 15, 12, 4, 59);
  static final staleAt = DateTime.utc(2026, 9, 15, 12, 5);
  static final twentyFourHours = kExplorationT0.add(const Duration(hours: 24));
  static const backoffSeconds = [300, 600, 900];
  static const retryAfterHeader = 600;
  static final retryAfterDeadline = DateTime.utc(2026, 9, 15, 12, 15);

  static FeedSnapshot revision1() {
    return FeedSnapshot.fromWire(
      [
        F3Fixtures.wireRecord(),
        F3Fixtures.wireRecord(id: '43', expiresAt: '2026-09-17T12:00:00Z'),
      ],
      now: kExplorationT0,
      revision: 1,
    );
  }
}

class F5Fixtures {
  static const paste =
      'ID\tGroup\tType\tName\tSignal\tDistance\r\n'
      'abc-123\tCosmic Signature\tData Site\tSansha Data Site\t100%\t1 AU\r\n'
      'DEF-456\tCosmic Signature\tWormhole\tUnstable Wormhole\r\n'
      'GHI-789\tCosmic Signature\t\t\r\n'
      'bad-id\tCosmic Signature\tData Site\tBroken\r\n'
      'ABC-123\tCosmic Signature\tData Site\tSansha Data Site';

  static const successMessage =
      'Imported 3 signatures: 2 added, 0 updated, 1 seen again.';

  static TrackedSignature abcExisting() => TrackedSignature(
    id: 'sig-abc',
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
    code: 'ABC-123',
    episodeId: 'episode-abc',
    type: SignatureType.data,
    name: 'Sansha Data Site',
    bookmark: 'Safe spot',
    notes: 'Keep this note',
    firstSeenAt: DateTime.utc(2026, 9, 15, 10),
    lastSeenAt: DateTime.utc(2026, 9, 15, 11),
  );

  static TrackedSignature old111() => TrackedSignature(
    id: 'sig-old',
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
    code: 'OLD-111',
    episodeId: 'episode-old',
    type: SignatureType.unknown,
    firstSeenAt: DateTime.utc(2026, 9, 14, 12),
    lastSeenAt: DateTime.utc(2026, 9, 14, 12),
  );

  static ImportPreview preview() {
    final parsed = ScannerImportParser.parse(paste);
    return ScannerMergePlanner.plan(
      parsed: parsed,
      scope: const NotebookScope(
        characterId: kCharacter7,
        systemId: kAlphaSystemId,
      ),
      observedAt: kExplorationT0,
      existing: [abcExisting(), old111()],
    );
  }
}

class F6Fixtures {
  static TrackedSignature age001() => TrackedSignature(
    id: 'age-001',
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
    code: 'AGE-001',
    episodeId: 'episode-age-001',
    lastSeenAt: kExplorationT0.subtract(const Duration(hours: 24)),
    editedAt: kExplorationT0.subtract(const Duration(minutes: 1)),
  );

  static TrackedSignature age002() => TrackedSignature(
    id: 'age-002',
    characterId: kCharacter7,
    systemId: kAlphaSystemId,
    code: 'AGE-002',
    episodeId: 'episode-age-002',
    lastSeenAt: kExplorationT0.subtract(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    ),
  );
}

class F7Systems {
  static const a = 101;
  static const b = 102;
  static const c = 103;
  static const d = 104;
  static const e = 105;
  static const f = 106;
  static const g = 107;
  static const h = 108;
  static const z = 109;
  static const j = 201;
  static const t = kTheraSystemId;
  static const u = kTurnurSystemId;
}

class F7Fixtures {
  static List<DirectedExplorationEdge> gateEdges() {
    const pairs = <(int, int)>[
      (F7Systems.a, F7Systems.b),
      (F7Systems.b, F7Systems.c),
      (F7Systems.c, F7Systems.d),
      (F7Systems.d, F7Systems.z),
      (F7Systems.a, F7Systems.e),
      (F7Systems.e, F7Systems.f),
      (F7Systems.f, F7Systems.g),
      (F7Systems.g, F7Systems.h),
      (F7Systems.h, F7Systems.z),
    ];
    return [
      for (final pair in pairs) ...[
        DirectedExplorationEdge(
          key: 'g-${pair.$1}-${pair.$2}',
          fromSystemId: pair.$1,
          toSystemId: pair.$2,
          canonicalKey: 'g-${pair.$1}-${pair.$2}',
        ),
        DirectedExplorationEdge(
          key: 'g-${pair.$2}-${pair.$1}',
          fromSystemId: pair.$2,
          toSystemId: pair.$1,
          canonicalKey: 'g-${pair.$2}-${pair.$1}',
        ),
      ],
    ];
  }

  static List<DirectedExplorationEdge> publicWormholes({
    bool btEol = false,
    bool tzCritical = false,
  }) {
    const pairs = <(int, int, String)>[
      (F7Systems.b, F7Systems.t, 'w01'),
      (F7Systems.t, F7Systems.z, 'tz'),
      (F7Systems.e, F7Systems.u, 'eu'),
      (F7Systems.u, F7Systems.z, 'uz'),
    ];
    return [
      for (final pair in pairs) ...[
        DirectedExplorationEdge(
          key: '${pair.$3}-fwd',
          fromSystemId: pair.$1,
          toSystemId: pair.$2,
          kind: 'wormhole',
          eol: pair.$3 == 'w01' && btEol,
          critical: pair.$3 == 'tz' && tzCritical,
          canonicalKey: pair.$3,
        ),
        DirectedExplorationEdge(
          key: '${pair.$3}-rev',
          fromSystemId: pair.$2,
          toSystemId: pair.$1,
          kind: 'wormhole',
          eol: pair.$3 == 'w01' && btEol,
          critical: pair.$3 == 'tz' && tzCritical,
          canonicalKey: '${pair.$3}-rev',
        ),
      ],
    ];
  }

  static List<DirectedExplorationEdge> privateCharacter7() {
    return const [
      DirectedExplorationEdge(
        key: 'p-aj-fwd',
        fromSystemId: F7Systems.a,
        toSystemId: F7Systems.j,
        kind: 'wormhole',
        privateOwner: kCharacter7,
        canonicalKey: 'p-aj',
      ),
      DirectedExplorationEdge(
        key: 'p-aj-rev',
        fromSystemId: F7Systems.j,
        toSystemId: F7Systems.a,
        kind: 'wormhole',
        privateOwner: kCharacter7,
        canonicalKey: 'p-aj-rev',
      ),
      DirectedExplorationEdge(
        key: 'p-jz-fwd',
        fromSystemId: F7Systems.j,
        toSystemId: F7Systems.z,
        kind: 'wormhole',
        privateOwner: kCharacter7,
        canonicalKey: 'p-jz',
      ),
      DirectedExplorationEdge(
        key: 'p-jz-rev',
        fromSystemId: F7Systems.z,
        toSystemId: F7Systems.j,
        kind: 'wormhole',
        privateOwner: kCharacter7,
        canonicalKey: 'p-jz-rev',
      ),
    ];
  }

  static GraphSnapshot graph({
    bool includePrivate = false,
    bool btEol = false,
    bool tzCritical = false,
    bool includeW02 = false,
  }) {
    final edges = [
      ...gateEdges(),
      ...publicWormholes(btEol: btEol, tzCritical: tzCritical),
      if (includePrivate) ...privateCharacter7(),
      if (includeW02)
        const DirectedExplorationEdge(
          key: 'w02-fwd',
          fromSystemId: F7Systems.b,
          toSystemId: F7Systems.t,
          kind: 'wormhole',
          canonicalKey: 'w02',
        ),
    ];
    return GraphSnapshot(
      nodes: {
        for (final edge in edges) ...[edge.fromSystemId, edge.toSystemId],
      },
      edges: edges,
      capturedAt: kExplorationT0,
    );
  }

  static const defaultPath = [
    F7Systems.a,
    F7Systems.b,
    F7Systems.t,
    F7Systems.z,
  ];
  static const preferHighsecPath = [
    F7Systems.a,
    F7Systems.e,
    F7Systems.f,
    F7Systems.g,
    F7Systems.h,
    F7Systems.z,
  ];
  static const eolPath = [F7Systems.a, F7Systems.e, F7Systems.u, F7Systems.z];
  static const privatePath = [F7Systems.a, F7Systems.j, F7Systems.z];
}

class F8Fixtures {
  static const bToTSummary =
      '1 gate jump to entrance; then 1 wormhole jump to Thera';
  static const zVia5GatesSummary =
      '5 gate jumps to entrance; then 1 wormhole jump to Thera';
}
