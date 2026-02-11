// lib/services/facility_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'dart:convert';

class FacilityService {
  final SupabaseClient _client;

  FacilityService(this._client);

  /// Searches for facilities near coordinates with proper null safety and sanitized queries
  Future<List<Facility>> searchNearbyFacilities({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    Map<String, bool>? attributeFilters,
  }) async {
    // Validate coordinates before using them
    if (latitude.isNaN || longitude.isNaN || !latitude.isFinite || !longitude.isFinite) {
      throw ArgumentError('Invalid coordinates provided');
    }

    try {
      final query = _client.from('facilities')
        ..select()
        ..rpc('calculate_distance', params: {
          'user_lat': latitude,
          'user_lng': longitude,
        })
        .lt('distance', radiusInKm * 1000); // Convert km to meters

      // Apply attribute filters if provided
      if (attributeFilters != null) {
        for (final entry in attributeFilters.entries) {
          if (entry.value) {
            query.eq(entry.key.toLowerCase(), true);
          }
        }
      }

      final response = await query;
      
      if (response != null) {
        return (response as List)
            .map((item) => Facility.fromJson(item))
            .where((facility) => 
                facility.latitude.isFinite && facility.longitude.isFinite)
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error searching nearby facilities: $e');
      rethrow;
    }
  }

  /// Searches facilities by name with sanitized input to prevent SQL wildcard injection
  Future<List<Facility>> searchFacilitiesByName({
    required String nameQuery,
    Map<String, bool>? attributeFilters,
  }) async {
    if (nameQuery.isEmpty) {
      return [];
    }

    try {
      // Sanitize the input to prevent SQL wildcard injection
      final sanitizedQuery = _sanitizeForLikeQuery(nameQuery);
      final wildcardQuery = '%$sanitizedQuery%';

      final query = _client.from('facilities')
        ..select()
        ..ilike('name', wildcardQuery);

      // Apply attribute filters if provided
      if (attributeFilters != null) {
        for (final entry in attributeFilters.entries) {
          if (entry.value) {
            query.eq(entry.key.toLowerCase(), true);
          }
        }
      }

      final response = await query;
      
      if (response != null) {
        return (response as List)
            .map((item) => Facility.fromJson(item))
            .where((facility) => 
                facility.latitude.isFinite && facility.longitude.isFinite)
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error searching facilities by name: $e');
      rethrow;
    }
  }

  /// Gets facility by ID with proper null safety
  Future<Facility?> getFacilityById(String id) async {
    try {
      final response = await _client
        .from('facilities')
        .select()
        .eq('id', id)
        .single();

      if (response != null) {
        final facility = Facility.fromJson(response as Map<String, dynamic>);
        
        // Verify coordinates are valid
        if (facility.latitude.isFinite && facility.longitude.isFinite) {
          return facility;
        }
      }
      return null;
    } catch (e) {
      print('Error getting facility by ID: $e');
      return null;
    }
  }

  /// Sanitizes user input to prevent SQL wildcard injection in ILIKE queries
  String _sanitizeForLikeQuery(String input) {
    // Escape special characters that have meaning in LIKE/ILIKE patterns
    return input
        .replaceAll('%', r'\%')  // Escape percent signs
        .replaceAll('_', r'\_')  // Escape underscores
        .replaceAll('[', r'\[')  // Escape square brackets
        .replaceAll(']', r'\]');
  }

  /// Parses PostGIS coordinates with null safety - used in multiple places
  (double, double)? parsePostgisCoordinates(dynamic coordinateData) {
    if (coordinateData == null) {
      return null;
    }

    try {
      if (coordinateData is Map<String, dynamic>) {
        // Handle GeoJSON-like formats
        if (coordinateData.containsKey('coordinates')) {
          final coords = coordinateData['coordinates'];
          if (coords is List && coords.length >= 2) {
            final lon = coords[0];
            final lat = coords[1];
            
            if (lon != null && lat != null) {
              final lonDouble = double.tryParse(lon.toString());
              final latDouble = double.tryParse(lat.toString());
              
              if (lonDouble != null && latDouble != null && 
                  lonDouble.isFinite && latDouble.isFinite) {
                return (lonDouble, latDouble);
              }
            }
          }
        } else if (coordinateData.containsKey('lng') && coordinateData.containsKey('lat')) {
          // Handle lat/lng object format
          final lon = coordinateData['lng'];
          final lat = coordinateData['lat'];
          
          if (lon != null && lat != null) {
            final lonDouble = double.tryParse(lon.toString());
            final latDouble = double.tryParse(lat.toString());
            
            if (lonDouble != null && latDouble != null &&
                lonDouble.isFinite && latDouble.isFinite) {
              return (lonDouble, latDouble);
            }
          }
        } else if (coordinateData.containsKey('longitude') && coordinateData.containsKey('latitude')) {
          // Handle longitude/latitude object format
          final lon = coordinateData['longitude'];
          final lat = coordinateData['latitude'];
          
          if (lon != null && lat != null) {
            final lonDouble = double.tryParse(lon.toString());
            final latDouble = double.tryParse(lat.toString());
            
            if (lonDouble != null && latDouble != null &&
                lonDouble.isFinite && latDouble.isFinite) {
              return (lonDouble, latDouble);
            }
          }
        }
      } else if (coordinateData is String) {
        // Attempt to parse common coordinate string formats
        final trimmed = coordinateData.trim();
        
        if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
          // Format: "(lon, lat)"
          final content = trimmed.substring(1, trimmed.length - 1);
          final parts = content.split(',').map((s) => s.trim()).toList();
          
          if (parts.length >= 2) {
            final lonDouble = double.tryParse(parts[0]);
            final latDouble = double.tryParse(parts[1]);
            
            if (lonDouble != null && latDouble != null &&
                lonDouble.isFinite && latDouble.isFinite) {
              return (lonDouble, latDouble);
            }
          }
        }
      }

      // If none of the above worked, try parsing as JSON string
      if (coordinateData is String) {
        try {
          final parsedJson = json.decode(coordinateData);
          return parsePostgisCoordinates(parsedJson);
        } catch (_) {
          // Continue to return null if parsing fails
        }
      }
    } catch (e) {
      print('Error parsing PostGIS coordinates: $e');
    }

    return null; // Return null if all parsing attempts fail
  }
}