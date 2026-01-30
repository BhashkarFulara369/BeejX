import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sensor_data.dart';

class BijukaViewModel extends ChangeNotifier {
  // --- Infrastructure ---
  late final DatabaseReference _dbRef;
  StreamSubscription<DatabaseEvent>? _subscription;

  // --- State ---
  // Real-time Values
  double _currentTemp = 0.0;
  double _currentHumidity = 0.0;
  double _currentPH = 0.0;
  
  // Relay States
  bool _isMainPumpOn = false;
  bool _isAuxLightOn = false;
  
  // Chart History
  final List<FlSpot> _tempHistory = [];
  double _minX = 0;
  double _maxX = 20;

  // Connection Status
  bool _isOnline = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Export Data Buffer
  final List<List<dynamic>> _exportData = [['Timestamp', 'Temperature', 'Humidity', 'pH']];

  // --- Getters ---
  double get currentTemp => _currentTemp;
  double get currentHumidity => _currentHumidity;
  double get currentPH => _currentPH;
  bool get isMainPumpOn => _isMainPumpOn;
  bool get isAuxLightOn => _isAuxLightOn;
  
  List<FlSpot> get tempHistory => _tempHistory;
  double get minX => _minX;
  double get maxX => _maxX;
  
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BijukaViewModel() {
    _initFirebase();
  }

  void _initFirebase() {
    try {
      _dbRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://beejx-a6af9-default-rtdb.asia-southeast1.firebasedatabase.app/'
      ).ref();

      _startListening();
    } catch (e) {
      _errorMessage = "Init Error: $e";
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startListening() {
    _subscription = _dbRef.onValue.listen(
      (event) {
        _isLoading = false;
        
        if (event.snapshot.value == null) {
          _isOnline = false;
          notifyListeners();
          return;
        }

        _isOnline = true;
        _errorMessage = null;

        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        _processData(data);
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      }
    );
  }

  void _processData(Map<String, dynamic> data) {
    // 1. Parse via Model (Type Safe)
    final sensorData = SensorData.fromMap(data);

    _isMainPumpOn = sensorData.isMainPumpOn;
    _isAuxLightOn = sensorData.isAuxLightOn;
    
    // 3. Update Chart History
    bool valuesChanged = sensorData.temperature != _currentTemp || sensorData.humidity != _currentHumidity;
    
    _currentTemp = sensorData.temperature;
    _currentHumidity = sensorData.humidity;
    _currentPH = sensorData.ph;

    if (valuesChanged) {
        final now = DateTime.now();
        final double timestamp = _tempHistory.length.toDouble();

        // Windowing Logic
        if (_tempHistory.length > 30) {
          _tempHistory.removeAt(0);
          _minX = _tempHistory.first.x;
          _maxX = _tempHistory.last.x + 1;
        } else {
          _maxX = 30; 
        }

        _tempHistory.add(FlSpot(timestamp, _currentTemp));
        _exportData.add([now.toIso8601String(), _currentTemp, _currentHumidity, _currentPH]);
    }
    
    notifyListeners();
  }

  // --- User Actions ---

  Future<void> toggleMainPump() async {
    // Optimistic Update
    _isMainPumpOn = !_isMainPumpOn;
    notifyListeners();
    
    try {
      await _dbRef.child('led/state').set(_isMainPumpOn ? 0 : 1);
    } catch (e) {
      _errorMessage = "Failed to switch pump";
      _isMainPumpOn = !_isMainPumpOn; // Revert
      notifyListeners();
    }
  }

  Future<void> toggleAuxLight() async {
    _isAuxLightOn = !_isAuxLightOn;
    notifyListeners();

    try {
      await _dbRef.child('second/state').set(_isAuxLightOn ? 0 : 1);
    } catch (e) {
       _errorMessage = "Failed to switch light";
       _isAuxLightOn = !_isAuxLightOn;
       notifyListeners();
    }
  }

  Future<String> exportCSV() async {
    try {
      String csvContent = _exportData.map((e) => e.join(",")).join("\n");
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final filename = "Bijuka_Report_${now.day}-${now.month}_${now.hour}-${now.minute}.csv";
      final path = "${directory.path}/$filename";
      final file = File(path);
      await file.writeAsString(csvContent);
      return path; // Return path on success
    } catch (e) {
      throw "Export Failed: $e";
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
