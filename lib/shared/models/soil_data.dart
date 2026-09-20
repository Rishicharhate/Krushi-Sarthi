/// Soil sensor data model.
class SoilData {
  final double moisture;
  final double temperature;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final String? moistureStatus;
  final String? phStatus;
  final String? overallStatus;
  final DateTime updatedAt;

  const SoilData({
    required this.moisture,
    required this.temperature,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    this.moistureStatus,
    this.phStatus,
    this.overallStatus,
    required this.updatedAt,
  });

  factory SoilData.fromJson(Map<String, dynamic> json) {
    return SoilData(
      moisture: (json['moisture'] as num).toDouble(),
      temperature: (json['temperature'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      nitrogen: (json['nitrogen'] as num).toDouble(),
      phosphorus: (json['phosphorus'] as num).toDouble(),
      potassium: (json['potassium'] as num).toDouble(),
      moistureStatus: json['moisture_status'] as String?,
      phStatus: json['ph_status'] as String?,
      overallStatus: json['overall_status'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'moisture': moisture,
    'temperature': temperature,
    'ph': ph,
    'nitrogen': nitrogen,
    'phosphorus': phosphorus,
    'potassium': potassium,
    'moisture_status': moistureStatus,
    'ph_status': phStatus,
    'overall_status': overallStatus,
    'updated_at': updatedAt.toIso8601String(),
  };
}

/// Single historical soil data point for charting.
class SoilHistoryPoint {
  final DateTime timestamp;
  final double value;

  const SoilHistoryPoint({required this.timestamp, required this.value});

  factory SoilHistoryPoint.fromJson(Map<String, dynamic> json) {
    return SoilHistoryPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Soil insight/recommendation from backend.
class SoilInsight {
  final String message;
  final String type; // 'info', 'warning', 'success'

  const SoilInsight({required this.message, required this.type});

  factory SoilInsight.fromJson(Map<String, dynamic> json) {
    return SoilInsight(
      message: json['message'] as String,
      type: json['type'] as String? ?? 'info',
    );
  }
}
