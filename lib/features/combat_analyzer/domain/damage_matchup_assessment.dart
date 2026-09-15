enum DamageMatchupAssessment { resistHole, neutral, strongResist, unknown }

DamageMatchupAssessment assessResist(double resist, double mean) {
  if (resist <= 20 || resist <= mean - 5) {
    return DamageMatchupAssessment.resistHole;
  }
  if (resist >= mean + 5) {
    return DamageMatchupAssessment.strongResist;
  }
  return DamageMatchupAssessment.neutral;
}
