import 'package:flutter/material.dart';

import 'responsive.dart';

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? responsive.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

class ResponsiveFormContainer extends StatelessWidget {
  const ResponsiveFormContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: responsive.maxFormWidth),
        child: child,
      ),
    );
  }
}

class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    return ResponsiveCenter(
      child: Padding(padding: padding ?? responsive.pagePadding, child: child),
    );
  }
}

class ResponsiveAppBuilder extends StatelessWidget {
  const ResponsiveAppBuilder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScaler = mediaQuery.textScaler.clamp(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.6,
    );

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScaler),
      child: child,
    );
  }
}
