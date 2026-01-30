class SensorData {
  final double temperature;
  final double humidity;
  final double ph;
  final bool isMainPumpOn;
  final bool isAuxLightOn;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.ph,
    required this.isMainPumpOn,
    required this.isAuxLightOn,
  });

  // Factory to parse the complex Firebase structure safely
  // Expected structure:
  // {
  //   "hydro": {"temp": 12.3, "humidity": 45.6, "pH": 7.0},
  //   "led": {"state": 0/1},
  //   "second": {"state": 0/1}
  // }
  factory SensorData.fromMap(Map<String, dynamic> data) {
    final hydro = data['hydro'] is Map ? data['hydro'] : {};
    
    // Parse numeric sensors safely
    final double temp = (hydro['temp'] as num?)?.toDouble() ?? 0.0;
    final double hum = (hydro['humidity'] as num?)?.toDouble() ?? 0.0;
    final double phVal = (hydro['pH'] as num?)?.toDouble() ?? 0.0;

    // Parse Relays (0 = ON, 1 = OFF in this system logic)
    final ledData = data['led'] is Map ? data['led'] : {};
    final secondData = data['second'] is Map ? data['second'] : {};

    final int ledState = (ledData['state'] as int?) ?? 1;
    final int secondState = (secondData['state'] as int?) ?? 1;

    return SensorData(
      temperature: temp, 
      humidity: hum, 
      ph: phVal,
      isMainPumpOn: ledState == 0,
      isAuxLightOn: secondState == 0,
    );
  }
}
