import 'package:flutter/material.dart';

import '../../../utility/colors.dart';

/// Icon + message + optional action, used for the error / empty states.
class ToursMessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ToursMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: TColors.placeholder),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: TColors.grey),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(actionLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: TColors.primary,
                side: const BorderSide(color: TColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
