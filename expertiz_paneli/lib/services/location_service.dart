import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  // Basit konum servisi - geocoding ve permission_handler olmadan
  
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
      return null;
    }
  }

  // Placeholder metod - personel_paneli için
  Stream<Position> getLocationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    // Geocoding paketi olmadan basit koordinat string döndür
    return 'Konum: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}
