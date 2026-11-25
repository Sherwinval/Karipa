/// Planning reference assumptions, not predictions from a user's fitness data.
({String duration, String assumption}) planningDuration(
    String activity, double km) {
  final minutesPerKm = switch (activity.toLowerCase()) {
    'walking' => 12.0,
    'jogging' => 8.0,
    'running' => 6.0,
    'cycling' => 3.0,
    _ => null,
  };
  if (minutesPerKm == null || !km.isFinite || km <= 0) {
    return (
      duration: 'Unavailable',
      assumption: 'Choose a valid activity and distance.'
    );
  }
  final minutes = (km * minutesPerKm).round();
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  final duration = hours == 0
      ? '$minutes min'
      : remainder == 0
          ? '$hours hr'
          : '$hours hr $remainder min';
  return (
    duration: '~$duration',
    assumption: activity.toLowerCase() == 'cycling'
        ? 'Assumes 20 km/h; not personalized.'
        : 'Assumes ${minutesPerKm.toInt()}:00/km pace; not personalized.'
  );
}
