/// AI disease detection result model.
class DiseaseResult {
  final String disease;
  final double confidence;
  final String? crop;
  final String? description;
  final String? symptoms;
  final String? recommendation;
  final String? imageUrl;
  final DateTime scannedAt;

  const DiseaseResult({
    required this.disease,
    required this.confidence,
    this.crop,
    this.description,
    this.symptoms,
    this.recommendation,
    this.imageUrl,
    required this.scannedAt,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    return DiseaseResult(
      disease: json['disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      crop: json['crop'] as String?,
      description: json['description'] as String?,
      symptoms: json['symptoms'] as String?,
      recommendation: json['recommendation'] as String?,
      imageUrl: json['image_url'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'disease': disease,
    'confidence': confidence,
    'crop': crop,
    'description': description,
    'symptoms': symptoms,
    'recommendation': recommendation,
    'image_url': imageUrl,
    'scanned_at': scannedAt.toIso8601String(),
  };

  bool get isHealthy => disease.toLowerCase().contains('healthy');
}

/// State for the disease detection flow.
enum DiseaseDetectionStatus { idle, imageSelected, uploading, analyzing, success, error }

class DiseaseDetectionState {
  final DiseaseDetectionStatus status;
  final String? imagePath;
  final DiseaseResult? result;
  final String? errorMessage;
  final double uploadProgress;

  const DiseaseDetectionState({
    this.status = DiseaseDetectionStatus.idle,
    this.imagePath,
    this.result,
    this.errorMessage,
    this.uploadProgress = 0.0,
  });

  DiseaseDetectionState copyWith({
    DiseaseDetectionStatus? status,
    String? imagePath,
    DiseaseResult? result,
    String? errorMessage,
    double? uploadProgress,
  }) {
    return DiseaseDetectionState(
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}
