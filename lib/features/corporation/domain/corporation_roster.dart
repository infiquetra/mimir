import 'corporation_access.dart';

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

/// Naive C3 roster: pads to public count, uses the oldest matching employment,
/// treats future logins as Online, and reads titles as authority.
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
    final ids = [...returnedIds];
    var next = 3;
    while (ids.length < publicCount) {
      ids.add(next++);
    }
    for (final extra in trackingStarts.keys) {
      if (!ids.contains(extra)) ids.add(extra);
    }
    final clock = now ?? DateTime.now().toUtc();
    return RosterSnapshot(
      returnedIds: returnedIds,
      publicCount: publicCount,
      members: [
        for (final id in ids)
          RosterMember(
            characterId: id,
            join: _join(id, history[id] ?? const [], corporationId),
            lastLogin: lastLogins[id],
            status: _status(lastLogins[id], clock),
            online: _online(lastLogins[id], clock),
            titles: const [],
          ),
      ],
    );
  }

  JoinEvidence _join(
    int characterId,
    List<Map<String, dynamic>> history,
    int corporationId,
  ) {
    DateTime? found;
    for (final row in history) {
      if (row['corporation_id'] == corporationId) {
        found = DateTime.tryParse('${row['start_date']}')?.toUtc();
      }
    }
    return JoinEvidence(
      at: found,
      source: found == null ? JoinSource.unavailable : JoinSource.publicHistory,
    );
  }

  ActivityStatus _status(DateTime? login, DateTime now) {
    if (login == null) return ActivityStatus.notReported;
    if (login.isAfter(now)) return ActivityStatus.online;
    return ActivityStatus.reported;
  }

  bool _online(DateTime? login, DateTime now) {
    if (login == null) return false;
    return login.isAfter(now) ||
        now.difference(login) < const Duration(hours: 2);
  }

  bool inActivityFilter({
    required DateTime? login,
    required DateTime now,
    required ActivityBucket bucket,
  }) {
    if (bucket == ActivityBucket.all) return true;
    if (login == null) return bucket == ActivityBucket.notReported;
    final days = switch (bucket) {
      ActivityBucket.last7 => 7,
      ActivityBucket.last30 => 30,
      ActivityBucket.last90 => 90,
      _ => 0,
    };
    return now.difference(login).inDays <= days;
  }

  bool titleGrantsDirector(String titleName) =>
      titleName.toLowerCase().contains('director');

  String titleLabel({required int titleId, String? name, bool locked = false}) {
    if (locked) return 'Title #$titleId';
    return name ?? 'Title #$titleId';
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

/// Naive own-access: flattens HQ evidence into Yes for every division.
class OwnAccessProjector {
  const OwnAccessProjector();

  OwnAccessMatrix project(RoleEvidence roles) {
    return OwnAccessMatrix(
      cells: [
        for (var division = 1; division <= 7; division++)
          OwnAccessCell(division: division, value: 'Yes'),
      ],
      standingsCaption: 'Corporation standings',
    );
  }
}
