import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MapboxRouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String maneuverModifier;

  const MapboxRouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.maneuverModifier,
  });

  factory MapboxRouteStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    return MapboxRouteStep(
      instruction: maneuver['instruction'] as String? ?? json['name'] as String? ?? '',
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0.0,
      maneuverType: maneuver['type'] as String? ?? 'straight',
      maneuverModifier: maneuver['modifier'] as String? ?? '',
    );
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get formattedTime {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) return '< 1 ph';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return '$hours giờ ${remainingMins > 0 ? '$remainingMins ph' : ''}';
    }
    return '$minutes ph';
  }
}

class MapboxRouteResult {
  final double distanceMeters;
  final double durationSeconds;
  final List<List<double>> coordinates; // [lng, lat]
  final List<MapboxRouteStep> steps;
  final String? encodedPolyline;

  const MapboxRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.coordinates,
    required this.steps,
    this.encodedPolyline,
  });

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) return '< 1 phút';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return '$hours giờ ${remainingMins > 0 ? '$remainingMins phút' : ''}';
    }
    return '$minutes phút';
  }
}

class MapboxService {
  static const String defaultToken =
      'pk.eyJ1IjoiZGluaHRhbnRoYW5oMTkiLCJhIjoiY210bnNsZ2V2MG14NzJ5cHN1ZjhzMjU3MiJ9.qM8oAp0Hb9ThJlBzvn0Qtw';

  /// Call Mapbox Directions API v5 to get the turn-by-turn route with polyline
  static Future<MapboxRouteResult?> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving', // 'driving', 'walking', 'cycling'
    String token = defaultToken,
  }) async {
    try {
      // We request geometries=polyline (Polyline5 format) for static map overlays
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$profile/$originLng,$originLat;$destLng,$destLat'
        '?alternatives=false&geometries=polyline&steps=true&overview=full&language=vi&access_token=$token',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final double distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final double duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

          // Polyline string from Mapbox (e.g. `_ibE_seK_c@...`)
          String? polylineStr;
          final geometry = firstRoute['geometry'];
          if (geometry is String) {
            polylineStr = geometry;
          }

          // Decode polyline into [lng, lat] coordinates
          final List<List<double>> coordinates = polylineStr != null
              ? _decodePolyline(polylineStr)
              : [];

          // Parse Steps
          final List<MapboxRouteStep> steps = [];
          final legs = firstRoute['legs'] as List<dynamic>? ?? [];
          if (legs.isNotEmpty) {
            final rawSteps = legs[0]['steps'] as List<dynamic>? ?? [];
            for (final s in rawSteps) {
              if (s is Map<String, dynamic>) {
                steps.add(MapboxRouteStep.fromJson(s));
              }
            }
          }

          return MapboxRouteResult(
            distanceMeters: distance,
            durationSeconds: duration,
            coordinates: coordinates,
            steps: steps,
            encodedPolyline: polylineStr,
          );
        }
      } else {
        debugPrint('[MapboxService] Directions API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[MapboxService] Directions API exception: $e');
    }
    return null;
  }

  /// Generate a static map image showing Start Pin, End Pin, and Route Polyline (like Google Maps)
  static String getStaticRouteImageUrl({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? encodedPolyline,
    String styleId = 'mapbox/streets-v12',
    int width = 1200,
    int height = 1200,
    int topPadding = 140,
    int bottomPadding = 260,
    int leftPadding = 60,
    int rightPadding = 60,
    String token = defaultToken,
  }) {
    // Pin A: Start (Blue Google Maps style 2563eb)
    // Pin B: Destination (Red/Pink e11d48)
    final pinA = 'pin-s-a+2563eb($originLng,$originLat)';
    final pinB = 'pin-s-b+e11d48($destLng,$destLat)';

    String overlays = '$pinA,$pinB';

    // If we have the encoded polyline path, add the Google Maps blue line: path-6+2563eb-0.9(...)
    if (encodedPolyline != null && encodedPolyline.isNotEmpty) {
      final encodedPath = Uri.encodeComponent(encodedPolyline);
      overlays = 'path-6+2563eb-0.9($encodedPath),$pinA,$pinB';
    }

    // Auto fit both pins and the path with calculated top/bottom padding to perfectly center in viewport
    return 'https://api.mapbox.com/styles/v1/$styleId/static/$overlays/auto/${width}x$height@2x?padding=$topPadding,$rightPadding,$bottomPadding,$leftPadding&access_token=$token';
  }

  /// Polyline decoder (Google / Mapbox polyline5)
  static List<List<double>> _decodePolyline(String encoded) {
    final List<List<double>> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // Mapbox coordinate format: [lng, lat]
      poly.add([lng / 1E5, lat / 1E5]);
    }
    return poly;
  }
}
