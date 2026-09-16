class FuelAlertEvent {
  const FuelAlertEvent({required this.remaining, this.fresh = true});

  final Duration remaining;
  final bool fresh;
}

class FuelAlertState {
  FuelAlertState({this.episodes = 0, this.armed = true});

  int episodes;
  bool armed;
}

/// First fresh remaining ≤24h opens an episode. Further critical/passed
/// observations in the same episode do not rearm. A fresh observation above
/// 24h rearms so a later ≤24h starts a new episode.
class CorporationFuelAlertReducer {
  const CorporationFuelAlertReducer();

  static const _critical = Duration(hours: 24);

  FuelAlertState reduce(FuelAlertState state, FuelAlertEvent event) {
    if (!event.fresh) return state;
    final critical = event.remaining <= _critical;
    if (critical) {
      if (state.armed) {
        state.episodes += 1;
        state.armed = false;
      }
      return state;
    }
    state.armed = true;
    return state;
  }
}
