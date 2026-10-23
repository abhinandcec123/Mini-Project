String formatDistanceKm(double distanceKm) {
  if (distanceKm == 0) return 'Same pin';
  if (distanceKm < 0.1) return '${(distanceKm * 1000).round()} m';
  return '${distanceKm.toStringAsFixed(1)} km';
}
