import 'package:flutter/material.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
    this.isFullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final EdgeInsets padding;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(16);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: enabled
          ? const [
              Color(0xFF18B8A8),
              Color(0xFF0F766E),
              Color(0xFF0B5F56),
            ]
          : const [
              Color(0xFFB9C4C3),
              Color(0xFFA6B3B1),
            ],
    );
    final content = icon == null
        ? child
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon!,
              const SizedBox(width: 8),
              child,
            ],
          );

    final button = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x330B1220),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                borderRadius: radius,
                splashColor: Colors.white.withValues(alpha: 0.14),
                highlightColor: Colors.white.withValues(alpha: 0.08),
                child: Padding(
                  padding: padding,
                  child: Center(
                    child: DefaultTextStyle(
                      style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Colors.white) ??
                          const TextStyle(color: Colors.white),
                      child: IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: enabled
                          ? [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.0),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isFullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
