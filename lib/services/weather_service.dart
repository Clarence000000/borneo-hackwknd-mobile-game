import 'package:farm_fintech/services/cloud_functions_service.dart';

/// Weather service that calls Cloud Function for disaster detection.
///
/// The actual weather check happens server-side (Cloud Function)
/// to prevent client-side manipulation.
class WeatherService {
  final CloudFunctionsService _cloud = CloudFunctionsService();

  /// Check for active disaster at the given GPS coordinates.
  ///
  /// Calls the `weatherCheck` Cloud Function which pings OpenWeather API
  /// and returns disaster status.
  Future<WeatherCheckResult> checkWeather(double lat, double lng) async {
    final result = await _cloud.checkWeather(lat, lng);
    
    return WeatherCheckResult(
      hasDisaster: result['hasDisaster'] ?? false,
      disasterType: result['disasterType'],
      severity: (result['severity'] as num?)?.toDouble() ?? 0.0,
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
