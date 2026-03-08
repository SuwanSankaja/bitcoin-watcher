import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class SignalBadge extends StatelessWidget {
  final SignalType signalType;
  final double? size;

  const SignalBadge({
    super.key,
    required this.signalType,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = signalType.displayName;
    final fontSize = size ?? 14.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.9,
        vertical: fontSize * 0.35,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(fontSize * 0.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getColor() {
    switch (signalType) {
      case SignalType.buy:
        return AppColors.buy;
      case SignalType.sell:
        return AppColors.sell;
      case SignalType.hold:
        return AppColors.hold;
    }
  }
}
