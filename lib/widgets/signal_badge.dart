import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';

class SignalBadge extends StatelessWidget {
  final SignalType signalType;
  final double? size;

  const SignalBadge({
    Key? key,
    required this.signalType,
    this.size,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = signalType.displayName;
    final fontSize = size ?? 14.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(fontSize * 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
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
