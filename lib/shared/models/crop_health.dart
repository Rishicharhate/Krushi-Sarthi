/// Crop health / NDVI data model.
class CropHealth {
  final double ndvi;
  final String healthStatus;
  final String crop;
  final DateTime date;
  final String? imageUrl;
  final double? previousNdvi;
  final double? ndviChange;

  const CropHealth({
    required this.ndvi,
    required this.healthStatus,
    required this.crop,
    required this.date,
    this.imageUrl,
    this.previousNdvi,
    this.ndviChange,
  });

  factory CropHealth.fromJson(Map<String, dynamic> json) {
    return CropHealth(
      ndvi: (json['ndvi'] as num).toDouble(),
      healthStatus: json['health_status'] as String,
      crop: json['crop'] as String,
      date: DateTime.parse(json['date'] as String),
      imageUrl: json['image_url'] as String?,
      previousNdvi: (json['previous_ndvi'] as num?)?.toDouble(),
      ndviChange: (json['ndvi_change'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ndvi': ndvi,
    'health_status': healthStatus,
    'crop': crop,
    'date': date.toIso8601String(),
    'image_url': imageUrl,
    'previous_ndvi': previousNdvi,
    'ndvi_change': ndviChange,
  };
}

/// NDVI history point for trend charts.
class NdviHistoryPoint {
  final DateTime date;
  final double ndvi;
  final String? healthStatus;

  const NdviHistoryPoint({
    required this.date,
    required this.ndvi,
    this.healthStatus,
  });

  factory NdviHistoryPoint.fromJson(Map<String, dynamic> json) {
    return NdviHistoryPoint(
      date: DateTime.parse(json['date'] as String),
      ndvi: (json['ndvi'] as num).toDouble(),
      healthStatus: json['health_status'] as String?,
    );
  }
}
