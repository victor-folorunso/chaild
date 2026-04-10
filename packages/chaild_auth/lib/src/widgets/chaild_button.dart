import 'package:flutter/material.dart';
import '../config/chaild_theme.dart';

enum ChaildButtonVariant { primary, secondary, ghost, danger }

class ChaildButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ChaildButtonVariant variant;
  final Widget? icon;
  final double? width;

  const ChaildButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = ChaildButtonVariant.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foreground(colorScheme),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final size = Size(width ?? double.infinity, 52);

    switch (variant) {
      case ChaildButtonVariant.primary:
        return SizedBox(
          width: width,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(minimumSize: size),
            child: child,
          ),
        );
      case ChaildButtonVariant.secondary:
        return SizedBox(
          width: width,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(minimumSize: size),
            child: child,
          ),
        );
      case ChaildButtonVariant.ghost:
        return SizedBox(
          width: width,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(minimumSize: size),
            child: child,
          ),
        );
      case ChaildButtonVariant.danger:
        return SizedBox(
          width: width,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: ChaildColors.error,
              foregroundColor: Colors.white,
              minimumSize: size,
            ),
            child: child,
          ),
        );
    }
  }

  Color _foreground(ColorScheme cs) {
    switch (variant) {
      case ChaildButtonVariant.primary:
      case ChaildButtonVariant.danger:
        return Colors.white;
      case ChaildButtonVariant.secondary:
      case ChaildButtonVariant.ghost:
        return cs.primary;
    }
  }
}

// ── Social Sign-In Buttons ────────────────────────────────────────────────────

class ChaildAppleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const ChaildAppleButton({super.key, this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apple,
                      color: isDark ? Colors.black : Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Continue with Apple',
                    style: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ChaildGoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const ChaildGoogleButton({super.key, this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google G logo via text — replace with asset if desired
                  const Text('G',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4285F4))),
                  const SizedBox(width: 8),
                  const Text('Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
      ),
    );
  }
}
