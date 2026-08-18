import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum SweetAlertIcon { success, error, warning }

class SweetAlert {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required SweetAlertIcon icon,
    String confirmButtonText = 'Entendido',
    String? cancelButtonText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'SweetAlert',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);

        Color iconColor;
        IconData iconData;
        String defaultBadge;

        switch (icon) {
          case SweetAlertIcon.success:
            iconColor = const Color(0xFF10B981); // Emerald Green
            iconData = Icons.check_circle_rounded;
            defaultBadge = 'ÉXITO';
            break;
          case SweetAlertIcon.error:
            iconColor = const Color(0xFFEF4444); // Red
            iconData = Icons.cancel_rounded;
            defaultBadge = 'ATENCIÓN';
            break;
          case SweetAlertIcon.warning:
            iconColor = const Color(0xFF06B6D4); // Electric Cyan (Matching app brand)
            iconData = Icons.info_outline_rounded;
            defaultBadge = 'INFORMACIÓN';
            break;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ScaleTransition(
          scale: curve,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Theme.of(context).cardColor,
            elevation: 12,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      defaultBadge,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated Icon Container
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.12),
                      border: Border.all(color: iconColor.withOpacity(0.4), width: 3),
                    ),
                    child: Icon(
                      iconData,
                      size: 40,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      if (cancelButtonText != null) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.withOpacity(0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              if (onCancel != null) onCancel();
                            },
                            child: Text(
                              cancelButtonText,
                              style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: iconColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            if (onConfirm != null) onConfirm();
                          },
                          child: Text(
                            confirmButtonText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
