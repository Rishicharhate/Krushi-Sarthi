/// Crop & fertilizer recommendation models (Phase 3) — mirror
/// backend/app/schemas.py CropRecommendationOut / FertilizerRecommendationOut.
/// Both are served by RandomForestClassifier models trained in
/// backend/app/ml/tabular/train.py.
class RecommendationAlternative {
  final String label;
  final double confidence;

  const RecommendationAlternative({required this.label, required this.confidence});

  factory RecommendationAlternative.fromJson(Map<String, dynamic> json) {
    return RecommendationAlternative(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

class CropRecommendation {
  final String crop;
  final double confidence;
  final List<RecommendationAlternative> alternatives;

  const CropRecommendation({
    required this.crop,
    required this.confidence,
    required this.alternatives,
  });

  factory CropRecommendation.fromJson(Map<String, dynamic> json) {
    return CropRecommendation(
      crop: json['crop'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((e) => RecommendationAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FertilizerRecommendation {
  final String fertilizer;
  final double confidence;
  final List<RecommendationAlternative> alternatives;

  const FertilizerRecommendation({
    required this.fertilizer,
    required this.confidence,
    required this.alternatives,
  });

  factory FertilizerRecommendation.fromJson(Map<String, dynamic> json) {
    return FertilizerRecommendation(
      fertilizer: json['fertilizer'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((e) => RecommendationAlternative.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
