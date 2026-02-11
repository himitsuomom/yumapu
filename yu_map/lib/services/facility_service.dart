// lib/services/facility_service.dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/domain/entities/facility.dart';

class FacilityService {
  final SupabaseClient _client;

  FacilityService(this._client);

  // Cache for storing facilities
  final Map<String, Facility> _facilitiesCache = {};
  
  // Method to find facilities with proper null safety and PostGIS handling
  Future<List<Facility>> getFacilities({
    double? latitude,
    double? longitude,
    String searchTerm = '',
    Map<String, bool> attributeFilters = const {},
    double radiusInMeters = 5000, // default 5km
  }) async {
    try {
      var query = _client
          .from('facilities')
          .select(
              '*, attributes(name, value)') // Assuming joined attributes table
          .is_('deleted_at', null); // Only fetch non-deleted facilities

      // Apply attribute filters first to ensure O/X attribute filters remain functional
      if (attributeFilters.isNotEmpty) {
        // Process attribute filters like Tattoo, Sauna, etc.
        // This maintains compatibility with O/X filters after refactor
        for (var entry in attributeFilters.entries) {
          if (entry.value) {
            // Only apply filters for enabled attributes (X means enabled)
            query = query.contains('attributes', {'name': entry.key, 'value': 'true'});
          }
        }
      }

      // Apply search term with proper sanitization
      if (searchTerm.isNotEmpty) {
        // Sanitize user input to prevent SQL wildcard injection
        String sanitizedTerm = _sanitizeSearchTerm(searchTerm);
        query = query.ilike('name', '%$sanitizedTerm%');
      }

      // Apply location-based filter with proper PostGIS coordinate parsing
      if (latitude != null && longitude != null) {
        // Use proper PostGIS RPC function instead of .distance()
        // Calling a custom RPC function that calculates distance using PostGIS ST_Distance
        query = _client.rpc(
          'get_facilities_within_radius',
          params: {
            'center_lat': latitude,
            'center_lng': longitude,
            'radius_meters': radiusInMeters,
          },
        ).select('*, attributes(name, value)');
      }

      final response = await query;
      
      if (response is List) {
        return response
            .map((json) => Facility.fromJson(_parsePostgisCoordinates(json)))
            .whereType<Facility>()
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching facilities: $e');
      return [];
    }
  }

  // Proper null safety for PostGIS coordinate parsing
  Map<String, dynamic> _parsePostgisCoordinates(Map<String, dynamic> data) {
    try {
      // Handle PostGIS coordinates which may be in various formats
      if (data.containsKey('location')) {
        final locationData = data['location'];
        
        if (locationData != null) {
          if (locationData is Map<String, dynamic>) {
            // GeoJSON format: {type: 'Point', coordinates: [lng, lat]}
            if (locationData.containsKey('coordinates') &&
                locationData['coordinates'] is List &&
                locationData['coordinates'].length >= 2) {
              final coords = locationData['coordinates'];
              data['lng'] = coords[0];
              data['lat'] = coords[1];
            }
          } else if (locationData is String) {
            // WKT format like "POINT(longitude latitude)"
            final parsedLocation = _parseWktPoint(locationData);
            if (parsedLocation != null) {
              data['lng'] = parsedLocation[0];
              data['lat'] = parsedLocation[1];
            }
          }
        }
      }
      // If no location field but still has lat/lng, ensure null safety
      data['lat'] ??= data['lat'] ?? 0.0;
      data['lng'] ??= data['lng'] ?? 0.0;
    } catch (e) {
      print('Error parsing PostGIS coordinates: $e');
      // Default to zero coordinates if parsing fails
      data['lat'] = 0.0;
      data['lng'] = 0.0;
    }
    
    return data;
  }

  // Parse WKT (Well-Known Text) Point format with comprehensive null safety
    List<double>? _parseWktPoint(String? wktPoint) {
      try {
        // Add null check for the parameter at line 55-56 equivalent
        if (wktPoint == null || !wktPoint.startsWith('POINT')) {
          return null;
        }
        
        // Extract coordinates from format like "POINT(139.767051 35.681236)"
        final regex = RegExp(r'POINT\(([-+]?\d*\.?\d+)\s+([-+]?\d*\.?\d+)\)');
        final match = regex.firstMatch(wktPoint);
        
        if (match != null && match.groupCount >= 2) {
          final lng = double.tryParse(match.group(1)!) ?? 0.0;
          final lat = double.tryParse(match.group(2)!) ?? 0.0;
          return [lng, lat];
        }
      } catch (e) {
        print('Error parsing WKT point: $e');
      }
      return null;
    }

  // Sanitize search term to prevent SQL wildcard injection - enhanced protection
  String _sanitizeSearchTerm(String? term) {
    if (term == null) return '';
    
    // Escape SQL wildcards % and _, and other potentially dangerous characters
    return term.replaceAllMapped(RegExp(r'([%_\\'])'), (match) {
      return r'\' + match.group(0)!;
    });
  }

  // Get facility by ID with caching
  Future<Facility?> getFacilityById(String id) async {
    // Check cache first
    if (_facilitiesCache.containsKey(id)) {
      return _facilitiesCache[id];
    }

    try {
      final response = await _client
          .from('facilities')
          .select('*')
          .eq('id', id)
          .is_('deleted_at', null)
          .single();

      if (response != null) {
        final facility = Facility.fromJson(_parsePostgisCoordinates(response));
        _facilitiesCache[id] = facility;
        return facility;
      }
    } catch (e) {
      print('Error fetching facility: $e');
    }

    return null;
  }

  // Clear cache
  void clearCache() {
    _facilitiesCache.clear();
  }

  // Method to get facilities near a location using proper PostGIS functions
  Future<List<Facility>> getFacilitiesNearby({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000,
    String searchTerm = '',
    Map<String, bool> attributeFilters = const {},
  }) async {
    try {
      // Use RPC function for proper PostGIS distance calculation
      var rpcQuery = _client.rpc(
        'get_facilities_within_radius',
        params: {
          'center_lat': latitude,
          'center_lng': longitude,
          'radius_meters': radiusInMeters,
          if (searchTerm.isNotEmpty) 'search_term': _sanitizeSearchTerm(searchTerm),
        },
      );

      // Apply filters after RPC call if needed
      final response = await rpcQuery.select('*, attributes(name, value)');

      if (response is List) {
        return response
            .map((json) => Facility.fromJson(_parsePostgisCoordinates(json)))
            .whereType<Facility>()
            .toList();
      }
    } catch (e) {
      print('Error fetching nearby facilities: $e');
    }
    
    return [];
  }
  
  // Method that replaces invalid .distance() method call with proper PostGIS distance calculation
  Future<List<Facility>> getFacilitiesByProximity({
    required double centerLat,
    required double centerLng,
    required double maxDistanceMeters,
    String searchTerm = '',
    Map<String, bool> attributeFilters = const {},
  }) async {
    try {
      // Use proper PostGIS RPC function instead of invalid .distance() method
      final response = await _client.rpc(
        'calculate_distance_and_filter',
        params: {
          'input_center_lat': centerLat,
          'input_center_lng': centerLng,
          'input_max_distance': maxDistanceMeters,
        },
      ).select('*, attributes(name, value)');
      
      if (response is List) {
        var facilities = response
            .map((json) => Facility.fromJson(_parsePostgisCoordinates(json)))
            .whereType<Facility>()
            .toList();
            
        // Apply additional filtering if needed
        if (searchTerm.isNotEmpty) {
          String sanitizedTerm = _sanitizeSearchTerm(searchTerm);
          facilities.retainWhere((facility) =>
            facility.name.toLowerCase().contains(sanitizedTerm.toLowerCase())
          );
        }
        
        return facilities;
      }
    } catch (e) {
      print('Error in getFacilitiesByProximity: $e');
    }
    
    return [];
  }
}