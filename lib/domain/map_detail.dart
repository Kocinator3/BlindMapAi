/// Population gates for background city dots. Capitals bypass every gate.
/// The largest non-capitals (2M+) remain visible at every zoom level.
int cityPopulationThreshold(double longitudeSpan) {
  if (longitudeSpan > 40) return 2000000;
  if (longitudeSpan > 15) return 500000;
  if (longitudeSpan > 5) return 100000;
  if (longitudeSpan > 1) return 20000;
  return 0;
}
