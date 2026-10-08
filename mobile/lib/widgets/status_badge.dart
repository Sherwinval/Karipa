import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: baseColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: baseColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
