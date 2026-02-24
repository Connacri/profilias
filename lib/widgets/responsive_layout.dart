import 'package:flutter/material.dart';

class ResponsiveInfo {
  const ResponsiveInfo({
    required this.width,
    required this.height,
    required this.isCompact,
    required this.isWide,
  });

  final double width;
  final double height;
  final bool isCompact;
  final bool isWide;
}

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.builder,
    this.maxWidth = 1100,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.topCenter,
  });

  final Widget Function(BuildContext context, ResponsiveInfo info) builder;
  final double maxWidth;
  final EdgeInsets padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final info = ResponsiveInfo(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          isCompact: constraints.maxWidth < 720,
          isWide: constraints.maxWidth >= 1024,
        );

        Widget child = builder(context, info);
        child = Padding(padding: padding, child: child);
        child = Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: child,
        );
      },
    );
  }
}
