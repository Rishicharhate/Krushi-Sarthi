import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Status levels for agricultural data indicators.
enum StatusLevel { healthy, attention, critical }

/// Semantic status badge with icon, text, and color.
/// Accessible: never relies on color alone — always shows icon + text.
class StatusBadge extends StatelessWidget {
  final StatusLevel status;
  final String? label;
  final double? fontSize;
  final bool showIcon;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.fontSize,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_icon, size: (fontSize ?? 12) + 2, color: _fgColor),
            const SizedBox(width: 4),
          ],
          Text(
            label ?? _defaultLabel,
            style: TextStyle(
              color: _fgColor,
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _fgColor => switch (status) {
    StatusLevel.healthy => AppColors.statusHealthy,
    StatusLevel.attention => AppColors.statusAttention,
    StatusLevel.critical => AppColors.statusCritical,
  };

  Color get _bgColor => switch (status) {
    StatusLevel.healthy => AppColors.statusHealthyBg,
    StatusLevel.attention => AppColors.statusAttentionBg,
    StatusLevel.critical => AppColors.statusCriticalBg,
  };

  IconData get _icon => switch (status) {
    StatusLevel.healthy => Icons.check_circle_rounded,
    StatusLevel.attention => Icons.warning_rounded,
    StatusLevel.critical => Icons.error_rounded,
  };

  String get _defaultLabel => switch (status) {
    StatusLevel.healthy => 'Healthy',
    StatusLevel.attention => 'Attention Required',
    StatusLevel.critical => 'Critical',
  };
}

/// Convenience constructors for common status types.
extension StatusBadgeHelpers on StatusBadge {
  static StatusLevel levelFromString(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
      case 'good':
      case 'normal':
      case 'optimal':
        return StatusLevel.healthy;
      case 'attention':
      case 'moderate':
      case 'warning':
      case 'low':
      case 'high':
        return StatusLevel.attention;
      case 'critical':
      case 'danger':
      case 'very low':
      case 'very high':
        return StatusLevel.critical;
      default:
        return StatusLevel.healthy;
    }
  }
}
