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

/// Naive C5 reducer: every fresh observation opens a new episode.
class CorporationFuelAlertReducer {
  const CorporationFuelAlertReducer();

  FuelAlertState reduce(FuelAlertState state, FuelAlertEvent event) {
    if (!event.fresh) return state;
    state.episodes += 1;
    return state;
  }
}
