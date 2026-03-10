import 'package:farm_fintech/config/constants.dart';

/// GPS location service for detecting ASEAN country.
///
/// TODO: Add geolocator package and implement.
/// For now, returns Malaysia as default.
class LocationService {
  /// Get the user's current GPS coordinates.
  Future<({double lat, double lng})> getCurrentLocation() async {
    // TODO: Use geolocator package
    // final position = await Geolocator.getCurrentPosition();
    // return (lat: position.latitude, lng: position.longitude);

    // Default: Kuala Lumpur
    return (lat: 3.1390, lng: 101.6869);
  }

  /// Detect the ASEAN country from GPS coordinates.
  /// Uses simple bounding-box heuristics.
  String detectCountry(double lat, double lng) {
    // Rough bounding boxes for ASEAN countries
    if (lat >= 1.0 && lat <= 7.5 && lng >= 100.0 && lng <= 119.5) return 'MY';
    if (lat >= -11.0 && lat <= 6.0 && lng >= 95.0 && lng <= 141.0) return 'ID';
    if (lat >= 1.15 && lat <= 1.48 && lng >= 103.6 && lng <= 104.1) return 'SG';
    if (lat >= 5.5 && lat <= 20.5 && lng >= 97.0 && lng <= 106.0) return 'TH';
    if (lat >= 4.5 && lat <= 21.0 && lng >= 116.0 && lng <= 127.0) return 'PH';
    if (lat >= 8.0 && lat <= 23.5 && lng >= 102.0 && lng <= 110.0) return 'VN';

    return 'MY'; // Fallback
  }

  /// Get the simulated currency for a country.
  String getCurrency(String country) {
    return kCountryCurrency[country] ?? 'XMYR';
  }
}
