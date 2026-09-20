/// Environmental monitoring data model.
class EnvironmentData {
  final double temperature;
  final double humidity;
  final double rainfall;
  final double windSpeed;
  final String? temperatureStatus;
  final String? humidityStatus;
  final DateTime updatedAt;

  const EnvironmentData({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    this.temperatureStatus,
    this.humidityStatus,
    required this.updatedAt,
  });

  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      rainfall: (json['rainfall'] as num).toDouble(),
      windSpeed: (json['wind_speed'] as num).toDouble(),
      temperatureStatus: json['temperature_status'] as String?,
      humidityStatus: json['humidity_status'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'rainfall': rainfall,
    'wind_speed': windSpeed,
    'temperature_status': temperatureStatus,
    'humidity_status': humidityStatus,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Historical environment data point for charting.
class EnvironmentHistoryPoint {
  final DateTime timestamp;
  final double value;

  const EnvironmentHistoryPoint({required this.timestamp, required this.value});

  factory EnvironmentHistoryPoint.fromJson(Map<String, dynamic> json) {
    return EnvironmentHistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Environment alert from backend.
class EnvironmentAlert {
  final String title;
  final String message;
  final String severity; // 'warning', 'danger', 'info'
  final DateTime timestamp;

  const EnvironmentAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
  });

  factory EnvironmentAlert.fromJson(Map<String, dynamic> json) {
    return EnvironmentAlert(
      title: json['title'] as String,
      message: json['message'] as String,
      severity: json['severity'] as String? ?? 'warning',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
