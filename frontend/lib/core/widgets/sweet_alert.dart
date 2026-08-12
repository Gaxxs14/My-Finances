import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SweetAlertIcon { success, error, warning }

class SweetAlert {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required SweetAlertIcon icon,
    String confirmButtonText = 'OK',
    String? cancelButtonText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) {
        Color iconColor;
        Widget iconWidget;

        switch (icon) {
          case SweetAlertIcon.success:
            iconColor = const Color(0xFF10B981);
            iconWidget = _AnimatedCheck();
            break;
          case SweetAlertIcon.error:
            iconColor = Colors.redAccent;
            iconWidget = _AnimatedCross();
            break;
          case SweetAlertIcon.warning:
            iconColor = Colors.amber;
            iconWidget = _AnimatedWarning();
            break;
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.surfaceDark,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icon Container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withOpacity(0.3), width: 4),
                    color: iconColor.withOpacity(0.08),
                  ),
                  child: Center(child: iconWidget),
                ),
                const SizedBox(height: 20),

                // 2. Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // 3. Description
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryDark,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cancelButtonText != null) ...[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (onCancel != null) onCancel();
                        },
                        child: Text(
                          cancelButtonText,
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (onConfirm != null) onConfirm();
                      },
                      child: Text(
                        confirmButtonText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Checkmark animation
class _AnimatedCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.check,
      size: 44,
      color: Color(0xFF10B981),
    );
  }
}

// Cross animation
class _AnimatedCross extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.close,
      size: 44,
      color: Colors.redAccent,
    );
  }
}

// Warning animation
class _AnimatedWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      '!',
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: Colors.amber,
      ),
    );
  }
}
