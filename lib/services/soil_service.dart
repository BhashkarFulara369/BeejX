import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoilService {
  final Dio _dio = Dio();
  
  // ISRIC SoilGrids API
  final String _baseUrl = "https://rest.isric.org/soilgrids/v2.0/properties/query";
  final String _prefsKey = "beejx_offline_soil_data";

  Future<Map<String, dynamic>?> getSoilInfo() async {
    String? currentState;
    String? currentCity;
    String locationName = "Unknown Location";

    try {
      // 1. Check Permissions & Get Location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return await _loadOfflineData();
      }
      if (permission == LocationPermission.deniedForever) return await _loadOfflineData();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      // 2. Get Address (Reverse Geocoding)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, 
          position.longitude
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          currentCity = place.locality; // e.g., Dehradun
          currentState = place.administrativeArea; // e.g., Uttarakhand
          locationName = "${place.locality}, ${place.administrativeArea}";
        }
      } catch (e) {
        print("Geocoding error: $e");
      }

      // 3. Call ISRIC API
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'lon': position.longitude,
          'lat': position.latitude,
          'property': ['phh2o', 'clay', 'sand', 'silt', 'nitrogen', 'soc', 'bdod'],
          'depth': '0-5cm',
          'value': 'mean', 
        },
      );

      if (response.statusCode == 200) {
        final soilData = _parseSoilData(response.data, locationName);
        await _saveOfflineData(soilData); // Save for offline use
        return soilData;
      } else {
        return await _loadOfflineData(state: currentState, city: currentCity);
      }

    } catch (e) {
      print("Error getting soil info: $e");
      return await _loadOfflineData(state: currentState, city: currentCity);
    }
  }

  Map<String, dynamic> _parseSoilData(Map<String, dynamic> data, String locationName) {
    double ph = 0.0;
    double clay = 0.0;
    double sand = 0.0;
    double silt = 0.0;
    double nitrogen = 0.0;
    double soc = 0.0;
    double bdod = 0.0;

    final layers = data['properties']['layers'] as List;
    
    for (var layer in layers) {
      final name = layer['name'];
      final depths = layer['depths'] as List;
      
      if (depths.isNotEmpty) {
        final values = depths[0]['values'];
        final mean = values['mean'];
        
        if (mean != null) {
          // Unit Conversions
          if (name == 'phh2o') ph = mean / 10.0; // pHx10 -> pH
          else if (name == 'clay') clay = mean / 10.0; // g/kg -> %
          else if (name == 'sand') sand = mean / 10.0; // g/kg -> %
          else if (name == 'silt') silt = mean / 10.0; // g/kg -> %
          else if (name == 'nitrogen') nitrogen = mean / 100.0; // cg/kg -> g/kg
          else if (name == 'soc') soc = mean / 100.0; // dg/kg -> % (approx, 10g/kg = 1%)
          else if (name == 'bdod') bdod = mean / 100.0; // cg/cm3 -> g/cm3
        }
      }
    }

    // Determine Soil Type (Simple Triangle approximation)
    String soilType = "Loam"; 
    if (clay >= 40) soilType = "Clay";
    else if (sand >= 50) {
       if (clay >= 20) soilType = "Sandy Clay Loam";
       else soilType = "Sandy Loam";
    } else if (silt >= 40) {
       if (clay >= 40) soilType = "Silty Clay";
       else soilType = "Silty Loam";
    }

    return {
      'location': locationName,
      'soil_type': soilType,
      'ph': ph.toStringAsFixed(1),
      'nitrogen': nitrogen.toStringAsFixed(2), // g/kg
      'organic_carbon': soc.toStringAsFixed(2), // %
      'bulk_density': bdod.toStringAsFixed(2), // g/cm3
      'texture': {
        'clay': clay.toStringAsFixed(1),
        'sand': sand.toStringAsFixed(1),
        'silt': silt.toStringAsFixed(1),
      },
      'description': "pH: ${ph.toStringAsFixed(1)} | SOC: ${soc.toStringAsFixed(1)}% | N: ${nitrogen.toStringAsFixed(2)} g/kg"
    };
  }

  Future<void> _saveOfflineData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(data));
  }

  /// Loads offline data. 
  /// Priority: 
  /// 1. Cached API result (SharedPreferences)
  /// 2. Local Asset JSON (soil_data.json) matching State/City
  Future<Map<String, dynamic>?> _loadOfflineData({String? state, String? city}) async {
    // 1. Try SharedPreferences (Last successful API fetch)
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_prefsKey);
      if (jsonString != null) {
        print("Loaded soil data from Cache.");
        return json.decode(jsonString);
      }
    } catch (e) {
      print("Error loading cache: $e");
    }

    // 2. Try Asset Fallback (soil_data.json)
    if (state != null && city != null) {
      try {
        print("Loading fallback soil data for $city, $state...");
        final String jsonString = await rootBundle.loadString('assets/soil_data.json');
        final Map<String, dynamic> allData = json.decode(jsonString);

        if (allData.containsKey(state)) {
           final Map<String, dynamic> stateData = allData[state];
           // Simple fuzzy match or direct match
           var cityKey = stateData.keys.firstWhere(
             (k) => k.toLowerCase().contains(city.toLowerCase()) || city.toLowerCase().contains(k.toLowerCase()),
             orElse: () => ""
           );

           if (cityKey.isNotEmpty) {
             final cityData = stateData[cityKey];
             // Enrich with default format keys if missing to avoid UI nulls
             return {
                'location': "$city, $state",
                'soil_type': cityData['soil_type'] ?? "Unknown",
                'ph': cityData['ph'] ?? "7.0",
                'nitrogen': cityData['nitrogen'] ?? "1.0",
                'organic_carbon': cityData['organic_carbon'] ?? "1.0",
                'bulk_density': cityData['bulk_density'] ?? "1.3",
                'description': cityData['description'] ?? "Offline Data",
                'is_offline_asset': true
             };
           }
        }
      } catch (e) {
        print("Error loading asset fallback: $e");
      }
    }

    return null;
  }
}
