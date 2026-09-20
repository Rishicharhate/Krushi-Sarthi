import '../../shared/models/soil_data.dart';
import '../../shared/models/environment_data.dart';
import '../../shared/models/crop_health.dart';
import '../../shared/models/disease_result.dart';
import '../../shared/models/government_scheme.dart';
import '../../shared/models/farm.dart';
import '../../shared/models/farmer_profile.dart';
import '../../shared/models/notification_item.dart';
import '../../shared/models/recommendation.dart';

/// Comprehensive realistic demo data for the final-year project presentation.
/// All values match the spec document.
class MockData {
  MockData._();

  // ── Farmer Profile ──
  static final farmerProfile = FarmerProfile(
    id: 'farmer_001',
    name: 'Rajesh Patil',
    mobile: '+91 98765 43210',
    village: 'Shirpur',
    district: 'Dhule',
    state: 'Maharashtra',
  );

  // ── Farms ──
  static final farms = [
    Farm(
      id: 'farm_001',
      name: 'Farm A',
      location: 'Shirpur, Dhule',
      area: 2.5,
      areaUnit: 'Acres',
      crop: 'Soybean',
      sowingDate: DateTime(2026, 6, 15),
      soilType: 'Black (Regur)',
      isActive: true,
      latitude: 21.32,
      longitude: 74.88,
    ),
    Farm(
      id: 'farm_002',
      name: 'Farm B',
      location: 'Shirpur, Dhule',
      area: 1.8,
      areaUnit: 'Acres',
      crop: 'Cotton',
      sowingDate: DateTime(2026, 6, 20),
      soilType: 'Alluvial',
      isActive: false,
      latitude: 21.33,
      longitude: 74.89,
    ),
  ];

  // ── Current Soil Data ──
  static final soilData = SoilData(
    moisture: 62,
    temperature: 27,
    ph: 6.8,
    nitrogen: 42,
    phosphorus: 28,
    potassium: 35,
    moistureStatus: 'Good',
    phStatus: 'Normal',
    overallStatus: 'Healthy',
    updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
  );

  // ── Soil History (7 days of moisture) ──
  static List<SoilHistoryPoint> soilMoistureHistory() {
    final now = DateTime.now();
    return [
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 6)), value: 45),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 5)), value: 52),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 4)), value: 58),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 3)), value: 55),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 2)), value: 60),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 1)), value: 65),
      SoilHistoryPoint(timestamp: now, value: 62),
    ];
  }

  static List<SoilHistoryPoint> soilPhHistory() {
    final now = DateTime.now();
    return [
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 6)), value: 6.5),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 5)), value: 6.6),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 4)), value: 6.7),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 3)), value: 6.9),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 2)), value: 6.8),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 1)), value: 6.7),
      SoilHistoryPoint(timestamp: now, value: 6.8),
    ];
  }

  static List<SoilHistoryPoint> soilTemperatureHistory() {
    final now = DateTime.now();
    return [
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 6)), value: 25),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 5)), value: 26),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 4)), value: 28),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 3)), value: 27),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 2)), value: 26),
      SoilHistoryPoint(timestamp: now.subtract(const Duration(days: 1)), value: 28),
      SoilHistoryPoint(timestamp: now, value: 27),
    ];
  }

  // ── Soil Insights ──
  static final soilInsights = [
    const SoilInsight(
      message: 'Your soil moisture is currently within the recommended range.',
      type: 'success',
    ),
    const SoilInsight(
      message: 'Soil pH is suitable for the selected crop.',
      type: 'success',
    ),
    const SoilInsight(
      message: 'NPK levels are adequate. Next fertilizer application recommended in 2 weeks.',
      type: 'info',
    ),
  ];

  // ── Current Environment Data ──
  static final environmentData = EnvironmentData(
    temperature: 28,
    humidity: 64,
    rainfall: 2.4,
    windSpeed: 12,
    temperatureStatus: 'Normal',
    humidityStatus: 'Normal',
    updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  // ── Environment History ──
  static List<EnvironmentHistoryPoint> temperatureHistory() {
    final now = DateTime.now();
    return [
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 6)), value: 26),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 5)), value: 29),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 4)), value: 31),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 3)), value: 28),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 2)), value: 27),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 1)), value: 30),
      EnvironmentHistoryPoint(timestamp: now, value: 28),
    ];
  }

  static List<EnvironmentHistoryPoint> humidityHistory() {
    final now = DateTime.now();
    return [
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 6)), value: 58),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 5)), value: 62),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 4)), value: 70),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 3)), value: 65),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 2)), value: 60),
      EnvironmentHistoryPoint(timestamp: now.subtract(const Duration(days: 1)), value: 68),
      EnvironmentHistoryPoint(timestamp: now, value: 64),
    ];
  }

  // ── Environment Alerts ──
  static final environmentAlerts = [
    EnvironmentAlert(
      title: 'Weather Alert',
      message: 'Rainfall conditions are expected. Check field conditions.',
      severity: 'warning',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    EnvironmentAlert(
      title: 'Temperature Advisory',
      message: 'Moderate temperatures expected this week. Good conditions for crop growth.',
      severity: 'info',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  // ── Crop Health / NDVI ──
  static final cropHealth = CropHealth(
    ndvi: 0.72,
    healthStatus: 'Healthy',
    crop: 'Soybean',
    date: DateTime(2026, 9, 19),
    previousNdvi: 0.68,
    ndviChange: 0.04,
  );

  // ── NDVI History ──
  static final ndviHistory = [
    NdviHistoryPoint(date: DateTime(2026, 8, 1), ndvi: 0.35, healthStatus: 'Moderate'),
    NdviHistoryPoint(date: DateTime(2026, 8, 8), ndvi: 0.42, healthStatus: 'Moderate'),
    NdviHistoryPoint(date: DateTime(2026, 8, 15), ndvi: 0.55, healthStatus: 'Good'),
    NdviHistoryPoint(date: DateTime(2026, 8, 22), ndvi: 0.62, healthStatus: 'Good'),
    NdviHistoryPoint(date: DateTime(2026, 8, 29), ndvi: 0.68, healthStatus: 'Healthy'),
    NdviHistoryPoint(date: DateTime(2026, 9, 5), ndvi: 0.70, healthStatus: 'Healthy'),
    NdviHistoryPoint(date: DateTime(2026, 9, 12), ndvi: 0.68, healthStatus: 'Healthy'),
    NdviHistoryPoint(date: DateTime(2026, 9, 19), ndvi: 0.72, healthStatus: 'Healthy'),
  ];

  // ── Disease Detection Demo Result ──
  static final diseaseResult = DiseaseResult(
    disease: 'Leaf Blight',
    confidence: 94.5,
    crop: 'Rice',
    description:
        'Leaf blight is a common fungal disease affecting rice crops. It causes elongated, grayish-green lesions on leaves that may eventually turn brown and dry out. The disease is favored by warm, humid conditions and can spread rapidly in poorly managed fields.',
    symptoms:
        'Elongated grayish-green lesions on leaves, browning of leaf tips, wilting of affected areas, reduced leaf area for photosynthesis.',
    recommendation:
        'Apply fungicide (Tricyclazole or Propiconazole) as per recommended dosage. Ensure proper field drainage. Maintain adequate spacing between plants. Remove and destroy infected plant material. Consider resistant rice varieties for next season.',
    scannedAt: DateTime(2026, 9, 19, 10, 30),
  );

  // ── Disease History ──
  static final diseaseHistory = [
    DiseaseResult(
      disease: 'Leaf Blight',
      confidence: 94.5,
      crop: 'Rice',
      description: 'Leaf blight is a common fungal disease affecting rice crops.',
      recommendation: 'Apply fungicide as per recommended dosage.',
      scannedAt: DateTime(2026, 9, 19, 10, 30),
    ),
    DiseaseResult(
      disease: 'Healthy Leaf',
      confidence: 97.2,
      crop: 'Cotton',
      description: 'No disease detected. The leaf appears healthy.',
      recommendation: 'Continue current maintenance practices.',
      scannedAt: DateTime(2026, 9, 15, 14, 45),
    ),
    DiseaseResult(
      disease: 'Powdery Mildew',
      confidence: 88.3,
      crop: 'Soybean',
      description: 'Powdery mildew appears as white powdery spots on leaves.',
      recommendation: 'Apply sulfur-based fungicide. Improve air circulation.',
      scannedAt: DateTime(2026, 9, 10, 9, 15),
    ),
  ];

  // ── Crop Recommendation Demo Result ──
  static const cropRecommendation = CropRecommendation(
    crop: 'Rice',
    confidence: 96.5,
    alternatives: [
      RecommendationAlternative(label: 'Jute', confidence: 2.0),
      RecommendationAlternative(label: 'Coconut', confidence: 1.0),
    ],
  );

  // ── Fertilizer Recommendation Demo Result ──
  static const fertilizerRecommendation = FertilizerRecommendation(
    fertilizer: 'Urea',
    confidence: 89.0,
    alternatives: [
      RecommendationAlternative(label: '28-28', confidence: 8.0),
      RecommendationAlternative(label: '20-20', confidence: 2.5),
    ],
  );

  // ── Government Schemes ──
  static final governmentSchemes = [
    GovernmentScheme(
      id: 'scheme_001',
      name: 'PM-KISAN',
      description:
          'Pradhan Mantri Kisan Samman Nidhi is a central sector scheme providing income support to all landholding farmer families across the country.',
      eligibility:
          'All landholding farmer families with cultivable landholding in their names are eligible. Certain categories of higher economic status are excluded.',
      benefits:
          'Financial assistance of ₹6,000 per year in three equal installments of ₹2,000 each, directly transferred to the bank accounts of eligible farmers.',
      documents: [
        'Aadhaar Card',
        'Land Records',
        'Bank Account Details',
        'Mobile Number',
      ],
      applicationProcess:
          'Apply through the PM-KISAN portal or visit your nearest Common Service Center (CSC). Submit required documents and verify Aadhaar details.',
      category: 'Financial Assistance',
      updatedAt: DateTime(2026, 9, 1),
    ),
    GovernmentScheme(
      id: 'scheme_002',
      name: 'PM Fasal Bima Yojana',
      description:
          'Pradhan Mantri Fasal Bima Yojana provides comprehensive crop insurance coverage against non-preventable natural risks.',
      eligibility:
          'All farmers including sharecroppers and tenant farmers growing notified crops in notified areas are eligible.',
      benefits:
          'Insurance coverage for crop loss due to natural calamities, pests, and diseases. Premium rates: 2% for Kharif, 1.5% for Rabi, and 5% for commercial/horticultural crops.',
      documents: [
        'Aadhaar Card',
        'Land Records / Tenancy Agreement',
        'Bank Account Details',
        'Sowing Certificate',
      ],
      applicationProcess:
          'Enroll through your bank, Common Service Center, or the PMFBY portal before the cut-off date for the crop season.',
      category: 'Insurance',
      updatedAt: DateTime(2026, 8, 15),
    ),
    GovernmentScheme(
      id: 'scheme_003',
      name: 'Soil Health Card Scheme',
      description:
          'The Soil Health Card Scheme provides soil health cards to farmers carrying crop-wise recommendations for nutrients and fertilizers.',
      eligibility: 'All farmers across India are eligible for free soil health cards.',
      benefits:
          'Free soil testing and health card with nutrient status and recommendations. Helps optimize fertilizer use and improve crop productivity.',
      documents: [
        'Aadhaar Card',
        'Land Details',
        'Farmer Registration Number',
      ],
      applicationProcess:
          'Visit your nearest Krishi Vigyan Kendra or contact the local agriculture department to request soil sampling.',
      category: 'Farmer Welfare',
      updatedAt: DateTime(2026, 7, 20),
    ),
    GovernmentScheme(
      id: 'scheme_004',
      name: 'PM Krishi Sinchai Yojana',
      description:
          'Pradhan Mantri Krishi Sinchai Yojana aims to expand cultivated area with assured irrigation and improve water use efficiency.',
      eligibility:
          'Farmers with agricultural land in water-scarce areas. Priority given to small and marginal farmers.',
      benefits:
          'Subsidized micro-irrigation systems (drip and sprinkler). Up to 55% subsidy for small farmers and 45% for others on micro-irrigation equipment.',
      documents: [
        'Aadhaar Card',
        'Land Ownership Records',
        'Bank Account Details',
        'Caste Certificate (if applicable)',
      ],
      applicationProcess:
          'Apply through the state agriculture department or online portal. Submit land details and select irrigation equipment.',
      category: 'Irrigation',
      updatedAt: DateTime(2026, 8, 1),
    ),
    GovernmentScheme(
      id: 'scheme_005',
      name: 'Sub-Mission on Agricultural Mechanization',
      description:
          'SMAM promotes farm mechanization by providing subsidies for purchase of agricultural machinery and equipment.',
      eligibility:
          'Individual farmers, farmer groups, FPOs, and cooperatives. Priority to small and marginal farmers.',
      benefits:
          'Subsidies ranging from 25% to 50% on purchase of farm machinery and equipment including tractors, harvesters, and precision farming tools.',
      documents: [
        'Aadhaar Card',
        'Land Records',
        'Bank Account Details',
        'Quotation from Authorized Dealer',
      ],
      applicationProcess:
          'Apply online through the DBT Agriculture portal. Select machinery, upload documents, and submit application.',
      category: 'Equipment',
      updatedAt: DateTime(2026, 7, 10),
    ),
  ];

  // ── Notifications ──
  static final notifications = [
    NotificationItem(
      id: 'notif_001',
      title: 'Soil Moisture Low',
      message: 'Soil moisture has dropped below the recommended level for Soybean crop.',
      category: 'Soil Alerts',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      isRead: false,
    ),
    NotificationItem(
      id: 'notif_002',
      title: 'Weather Alert',
      message: 'Rainfall conditions expected in the next 24 hours. Check field drainage.',
      category: 'Environmental Alerts',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
    ),
    NotificationItem(
      id: 'notif_003',
      title: 'NDVI Update Available',
      message: 'New satellite observation available for Farm A. NDVI: 0.72 (Healthy).',
      category: 'Crop Health Alerts',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      isRead: true,
    ),
    NotificationItem(
      id: 'notif_004',
      title: 'Disease Scan Complete',
      message: 'AI analysis complete for your recent leaf scan. Leaf Blight detected with 94.5% confidence.',
      category: 'Disease Alerts',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    NotificationItem(
      id: 'notif_005',
      title: 'New Scheme Available',
      message: 'PM Krishi Sinchai Yojana applications are now open for your district.',
      category: 'Scheme Updates',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
    NotificationItem(
      id: 'notif_006',
      title: 'High Temperature Alert',
      message: 'Temperature is expected to reach 38°C tomorrow. Consider protective measures for crops.',
      category: 'Environmental Alerts',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];
}
