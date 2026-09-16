import 'corporation_access.dart';
import 'corporation_oracles.dart';

enum JoinSource { tracking, publicHistory, unavailable }

enum ActivityBucket { all, last7, last30, last90, notReported }

enum ActivityStatus { reported, notReported, unknown, online }

class JoinEvidence {
  const JoinEvidence({this.at, this.source = JoinSource.unavailable});

  final DateTime? at;
  final JoinSource source;
}

class RosterMember {
  const RosterMember({
    required this.characterId,
    this.name = '',
    this.join = const JoinEvidence(),
    this.lastLogin,
    this.status = ActivityStatus.reported,
    this.titles = const [],
    this.online = false,
  });

  final int characterId;
  final String name;
  final JoinEvidence join;
  final DateTime? lastLogin;
  final ActivityStatus status;
  final List<String> titles;
  final bool online;
}

class RosterSnapshot {
  const RosterSnapshot({
    this.returnedIds = const [],
    this.publicCount = 0,
    this.members = const [],
    this.trackingLocked = false,
    this.rolesLocked = false,
    this.titlesLocked = false,
  });

  final List<int> returnedIds;
  final int publicCount;
  final List<RosterMember> members;
  final bool trackingLocked;
  final bool rolesLocked;
  final bool titlesLocked;

  bool get reportsCountMismatch => members.length != publicCount;
}

/// Roster membership is the returned ID set. Tracking/history never invent members.
class CorporationRoster {
  const CorporationRoster();

  RosterSnapshot assemble({
    required List<int> returnedIds,
    required int publicCount,
    Map<int, List<Map<String, dynamic>>> history = const {},
    Map<int, DateTime> trackingStarts = const {},
    Map<int, DateTime?> lastLogins = const {},
    DateTime? now,
    int corporationId = 7001,
  }) {
    final clock = now ?? DateTime.now().toUtc();
    final ids = <int>[];
    final seen = <int>{};
    for (final id in returnedIds) {
      if (seen.add(id)) ids.add(id);
    }
    return RosterSnapshot(
      returnedIds: List<int>.unmodifiable(returnedIds),
      publicCount: publicCount,
      members: [
        for (final id in ids)
          RosterMember(
            characterId: id,
            join: _join(
              history[id] ?? const [],
              corporationId,
              trackingStarts[id],
            ),
            lastLogin: lastLogins[id],
            status: _status(lastLogins[id], clock),
            online: false,
            titles: const [],
          ),
      ],
    );
  }

  JoinEvidence _join(
    List<Map<String, dynamic>> history,
    int corporationId,
    DateTime? trackingStart,
  ) {
    if (trackingStart != null) {
      return JoinEvidence(
        at: trackingStart.toUtc(),
        source: JoinSource.tracking,
      );
    }
    final at = RosterOracle().currentJoin(history, corporationId);
    if (at == null) return const JoinEvidence();
    return JoinEvidence(at: at, source: JoinSource.publicHistory);
  }

  ActivityStatus _status(DateTime? login, DateTime now) {
    if (login == null) return ActivityStatus.notReported;
    if (login.isAfter(now)) return ActivityStatus.unknown;
    return ActivityStatus.reported;
  }

  bool inActivityFilter({
    required DateTime? login,
    required DateTime now,
    required ActivityBucket bucket,
  }) {
    if (bucket == ActivityBucket.all) return true;
    if (login == null) return bucket == ActivityBucket.notReported;
    if (bucket == ActivityBucket.notReported) return false;
    if (login.isAfter(now)) return false;
    final window = switch (bucket) {
      ActivityBucket.last7 => const Duration(days: 7),
      ActivityBucket.last30 => const Duration(days: 30),
      ActivityBucket.last90 => const Duration(days: 90),
      _ => Duration.zero,
    };
    return now.difference(login) <= window;
  }

  bool titleGrantsDirector(String titleName) => false;

  String titleLabel({required int titleId, String? name, bool locked = false}) {
    if (locked) return 'title unavailable';
    if (name != null && name.isNotEmpty) return name;
    return 'title unavailable';
  }
}

class OwnAccessCell {
  const OwnAccessCell({required this.division, required this.value});
  final int division;
  final String value;
}

class OwnAccessMatrix {
  const OwnAccessMatrix({this.cells = const [], this.standingsCaption = ''});
  final List<OwnAccessCell> cells;
  final String standingsCaption;
}

/// Seven-division reported-role matrix. Not an ACL and not corporate standings.
class OwnAccessProjector {
  const OwnAccessProjector();

  static final _division = RegExp(r'_(\d+)$');

  OwnAccessMatrix project(RoleEvidence roles) {
    final yes = <int>{};
    for (final name in [
      ...roles.general,
      ...roles.hq,
      ...roles.base,
      ...roles.other,
      ...roles.grantable,
    ]) {
      final match = _division.firstMatch(name);
      if (match != null) yes.add(int.parse(match.group(1)!));
    }
    return OwnAccessMatrix(
      cells: [
        for (var division = 1; division <= 7; division++)
          OwnAccessCell(
            division: division,
            value: yes.contains(division) ? 'Yes' : 'Not reported',
          ),
      ],
      standingsCaption: 'My NPC standings',
    );
  }
}
