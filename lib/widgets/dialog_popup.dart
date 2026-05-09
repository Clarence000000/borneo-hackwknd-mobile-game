import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';

/// Reusable dialog popup for tutorial messages and financial advisor warnings.
class DialogPopup extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onDismiss;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;

  const DialogPopup({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = 'Got it!',
    this.onDismiss,
    this.icon,
    this.iconColor,
    this.textColor,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    IconData? icon,
    Color? iconColor,
    Color? textColor,
  }) {
    return showDialog(
      context: context,
      builder: (_) => Center(
        child: DialogPopup(
          title: title,
          message: message,
          buttonText: buttonText,
          icon: icon,
          iconColor: iconColor,
          textColor: textColor,
          onDismiss: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            margin: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.17),
                  GameColors.uiPanel.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: GameColors.uiHighlight.withValues(alpha: 0.22),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: iconColor ?? GameColors.uiGold, size: 36),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? GameColors.uiText,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      color: textColor?.withOpacity(0.8) ?? GameColors.uiTextDim,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameColors.uiHighlight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onDismiss,
                      child: Text(
                        buttonText ?? 'Got it!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
