import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Score-based badge for the hodler app.
/// Shows accumulation score tier instead of BUY/SELL/HOLD.
class SignalBadge extends StatelessWidget {
  final String signalType;
  final double? accumulationScore;
  final double size;

  const SignalBadge({
    super.key,
    required this.signalType,
    this.accumulationScore,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    final score = accumulationScore ?? 0;
    final isBuyZone = signalType == 'BUY';

    final Color color;
    final String label;
    final IconData icon;

    if (isBuyZone) {
      if (score >= 85) {
        color = AppColors.buy;
        label = 'STRONG BUY ZONE';
        icon = Icons.local_fire_department_rounded;
      } else {
        color = const Color(0xFF4ADE80);
        label = 'BUY ZONE';
        icon = Icons.trending_up_rounded;
      }
    } else {
      color = AppColors.hold;
      label = 'MONITORING';
      icon = Icons.radar_rounded;
    }

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: size * 0.9, vertical: size * 0.45),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: size),
          SizedBox(width: size * 0.4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: size * 0.72,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
