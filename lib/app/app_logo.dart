import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logoColor = colorScheme.primary;
    final backgroundColor = colorScheme.primaryContainer;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.34,
              height: size * 0.78,
              decoration: BoxDecoration(
                color: logoColor,
                borderRadius: BorderRadius.circular(size * 0.18),
              ),
            ),
            Positioned(
              top: size * 0.16,
              child: Container(
                width: size * 0.18,
                height: size * 0.18,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.16,
              child: Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
