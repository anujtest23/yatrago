import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lng;

  GeocodingResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'] ?? '',
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lon'].toString()),
    );
  }
}

class ReverseGeocodeResult {
  final String displayName;
  final String? city;
  final String? state;

  ReverseGeocodeResult({required this.displayName, this.city, this.state});
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000;
  int get durationMinutes => (durationSeconds / 60).round();
}

class MapService {
  // Nominatim — free OpenStreetMap geocoding, no API key
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';

  // OSRM — free open-source routing, no API key
  static const String _osrmBase = 'https://router.project-osrm.org';

  static const Map<String, String> _headers = {'User-Agent': 'YatraGoApp/1.0'};

  /// Search for a place by name (forward geocoding)
  /// Biased to Nepal results
  static Future<List<GeocodingResult>> searchPlace(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_nominatimBase/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&countrycodes=np'
        '&limit=8'
        '&addressdetails=1',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => GeocodingResult.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocode — get place name from coordinates
  static Future<String> reverseGeocode(double lat, double lng) async {
    final result = await reverseGeocodeStructured(lat, lng);
    return result.displayName;
  }

  /// Reverse geocode — get place name plus structured city/state from coordinates
  static Future<ReverseGeocodeResult> reverseGeocodeStructured(
    double lat,
    double lng,
  ) async {
    try {
      final uri = Uri.parse(
        '$_nominatimBase/reverse'
        '?lat=$lat&lon=$lng'
        '&format=json'
        '&addressdetails=1',
      );

      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] ?? {};

        // Build a short readable name: prefer city/town/village + suburb
        final parts = <String>[];
        if (address['suburb'] != null) parts.add(address['suburb']);
        String? city;
        if (address['city'] != null) {
          city = address['city'];
        } else if (address['town'] != null) {
          city = address['town'];
        } else if (address['village'] != null) {
          city = address['village'];
        } else if (address['county'] != null) {
          city = address['county'];
        }
        if (city != null) parts.add(city);
        final state = address['state'] as String?;

        final displayName = parts.isNotEmpty
            ? parts.join(', ')
            : (data['display_name']?.toString().split(',').take(2).join(',') ??
                'Selected location');

        return ReverseGeocodeResult(
          displayName: displayName,
          city: city,
          state: state,
        );
      }
      return ReverseGeocodeResult(displayName: 'Selected location');
    } catch (_) {
      return ReverseGeocodeResult(displayName: 'Selected location');
    }
  }

  /// Get a driving route between two points using OSRM
  /// Returns polyline points, distance, and duration
  static Future<RouteResult?> getRoute(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
  }) async {
    try {
      // Build coordinate string: lng,lat;lng,lat;...
      final coords = [
        '${origin.longitude},${origin.latitude}',
        ...waypoints.map((w) => '${w.longitude},${w.latitude}'),
        '${destination.longitude},${destination.latitude}',
      ].join(';');

      final uri = Uri.parse(
        '$_osrmBase/route/v1/driving/$coords'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final coordinates = route['geometry']['coordinates'] as List;

          final points = coordinates
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();

          return RouteResult(
            points: points,
            distanceMeters: (route['distance'] as num).toDouble(),
            durationSeconds: (route['duration'] as num).toDouble(),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
