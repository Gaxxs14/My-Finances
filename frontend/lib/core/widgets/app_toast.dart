import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scaffold = ScaffoldMessenger.maybeOf(context);
    if (scaffold == null) return;

    scaffold.hideCurrentSnackBar();

    Color bgColor;
    Color borderColor;
    IconData iconData;

    switch (type) {
      case AppToastType.success:
        bgColor = const Color(0xFF064E3B);
        borderColor = const Color(0xFF10B981);
        iconData = Icons.check_circle_rounded;
        break;
      case AppToastType.error:
        bgColor = const Color(0xFF7F1D1D);
        borderColor = const Color(0xFFEF4444);
        iconData = Icons.error_rounded;
        break;
      case AppToastType.warning:
        bgColor = const Color(0xFF78350F);
        borderColor = const Color(0xFFF59E0B);
        iconData = Icons.warning_amber_rounded;
        break;
      case AppToastType.info:
        bgColor = const Color(0xFF1E3A8A);
        borderColor = AppTheme.primaryDark;
        iconData = Icons.info_rounded;
        break;
    }

    scaffold.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: duration,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.25),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(iconData, color: borderColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
