/// Weather service that calls Cloud Function for disaster detection.
///
/// The actual weather check happens server-side (Cloud Function)
/// to prevent client-side manipulation.
class WeatherService {
  /// Check for active disaster at the given GPS coordinates.
  ///
  /// Calls the `weatherCheck` Cloud Function which pings OpenWeather API
  /// and returns disaster status.
  Future<WeatherCheckResult> checkWeather(double lat, double lng) async {
    // TODO: Call Cloud Function via Firebase
    // final result = await FirebaseFunctions.instance
    //     .httpsCallable('weatherCheck')
    //     .call({'lat': lat, 'lng': lng});

    // Demo: return no disaster
    return WeatherCheckResult(
      hasDisaster: false,
      disasterType: null,
      severity: 0,
    );
  }
}

class WeatherCheckResult {
  final bool hasDisaster;
  final String? disasterType;
  final double severity;

  const WeatherCheckResult({
    required this.hasDisaster,
    this.disasterType,
    this.severity = 0,
  });
}
