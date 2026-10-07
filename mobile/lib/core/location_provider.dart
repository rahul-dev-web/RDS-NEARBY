import 'app_logger.dart';

abstract interface class LocationProvider {
  Future<LocationContext?> getCurrentLocation();
}

class LocationContext {
  const LocationContext({this.latitude, this.longitude, this.locality});

  final double? latitude;
  final double? longitude;
  final String? locality;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class LocalityFallbackProvider implements LocationProvider {
  const LocalityFallbackProvider(this.locality);

  final String locality;

  @override
  Future<LocationContext?> getCurrentLocation() async {
    AppLogger.info('Using locality fallback: $locality');
    return LocationContext(locality: locality);
  }
}

class UnavailableLocationProvider implements LocationProvider {
  const UnavailableLocationProvider();

  @override
  Future<LocationContext?> getCurrentLocation() async => null;
}