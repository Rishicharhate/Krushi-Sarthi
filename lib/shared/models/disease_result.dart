/// A runner-up diagnosis, shown when the model isn't highly confident.
class DiseaseAlternative {
  final String disease;
  final double confidence;
  final String? symptoms;

  const DiseaseAlternative({required this.disease, required this.confidence, this.symptoms});

  factory DiseaseAlternative.fromJson(Map<String, dynamic> json) {
    return DiseaseAlternative(
      disease: json['disease'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      symptoms: json['symptoms'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'disease': disease,
    'confidence': confidence,
    'symptoms': symptoms,
  };
}

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

  /// "high" | "medium" | "low" — only present on a fresh scan, not history.
  final String? certainty;
  final String? caution;
  final List<DiseaseAlternative> alternatives;

  /// Set on a fresh scan; what POST /api/disease/feedback refers to.
  final String? scanId;

  /// True only when the backend runs with FEEDBACK_MODE (testing builds) —
  /// the result screen then asks the tester whether the diagnosis was right.
  final bool feedbackEnabled;

  const DiseaseResult({
    required this.disease,
    required this.confidence,
    this.crop,
    this.description,
    this.symptoms,
    this.recommendation,
    this.imageUrl,
    required this.scannedAt,
    this.certainty,
    this.caution,
    this.alternatives = const [],
    this.scanId,
    this.feedbackEnabled = false,
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
      certainty: json['certainty'] as String?,
      caution: json['caution'] as String?,
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((e) => DiseaseAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
      scanId: json['scan_id'] as String?,
      feedbackEnabled: json['feedback_enabled'] as bool? ?? false,
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
    'certainty': certainty,
    'caution': caution,
    'alternatives': alternatives.map((a) => a.toJson()).toList(),
    'scan_id': scanId,
    'feedback_enabled': feedbackEnabled,
  };

  bool get isHealthy => disease.toLowerCase().contains('healthy');
}

/// One class the disease model can predict (GET /api/disease/labels).
class DiseaseLabel {
  final String label; // model vocabulary — sent back in feedback
  final String displayName;
  final String? crop;

  const DiseaseLabel({required this.label, required this.displayName, this.crop});

  factory DiseaseLabel.fromJson(Map<String, dynamic> json) => DiseaseLabel(
    label: json['label'] as String,
    displayName: json['display_name'] as String,
    crop: json['crop'] as String?,
  );
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
